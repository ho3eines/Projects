# fix-double-utf8.ps1 — تعمیر داده‌های با کدگذاری دوبل UTF-8
#
# مشکل: برخی شرح/نام‌ها موقع درج، بایت‌های UTF-8 با جدول Windows-1256 (cp1256)
# خوانده شده‌اند و به‌جای متن فارسی، نویسه‌هایی مثل «ط¯ط±غŒ» یا کاراکترهای
# U+0080–U+00FF ذخیره شده‌اند (مثل «¯…±»). این اسکریپت رشتهٔ خراب را با
# cp1256 به بایت برمی‌گرداند و سپس UTF-8 دیکد می‌کند — دقیقاً وارون خرابی.
#
# ایمنی:
#   * فقط ردیف‌هایی تعمیر می‌شوند که (الف) به‌صورت UTF-8 معتبر دیکد شوند و
#     (ب) نتیجه حداقل یک نویسهٔ فارسی/عربی (U+0600–U+06FF) داشته باشد؛
#     رشته‌های سالم لاتین/فارسی هرگز دست نمی‌خورند.
#   * حالت خشک (dry) پیش‌فرض است — با پرچم -Apply واقعاً UPDATE می‌شود.
#
# اجرا:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/fix-double-utf8.ps1        # اسکن (خشک)
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/fix-double-utf8.ps1 -Apply  # تعمیر واقعی
#
# آرگومان‌ها:
#   -ConnectionString  اتصال SQL (پیش‌فرض: سرور محلی توسعه)
#   -Apply             واقعاً اعمال کند (بدون آن فقط گزارش می‌دهد)

param(
    [string]$ConnectionString = "Server=localhost;Database=TarazinMaster;User Id=sa;Password=123456;TrustServerCertificate=True;Encrypt=False",
    [switch]$Apply,
    [string]$LogFile = ""
)

# خروجی کنسول ویندوز UTF-8 نیست؛ گزارش را (به‌صورت اختیاری) با -LogFile به فایل
# UTF-8 بنویس تا فارسی درست دیده شود.
$logOut = if ($LogFile -ne "") { New-Object System.IO.StreamWriter($LogFile, $false, (New-Object System.Text.UTF8Encoding($false))) } else { $null }
function Write-Log([string]$msg) {
    Write-Output $msg
    if ($null -ne $logOut) { $logOut.WriteLine($msg) }
}

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Data

$cp1256 = [System.Text.Encoding]::GetEncoding(1256)
# throwOnInvalidBytes = true: اگر بایت‌ها UTF-8 معتبر نبودند استثنا می‌دهد → امن.
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

# ستون‌های شناخته‌شدهٔ دارای خطر دوبل-UTF8: (schema, table, column, keyColumn)
$targets = @(
    @('treasury',   'CashMovements', 'Description',      'MovementNumber'),
    @('accounting',  'Documents',    'CounterPartyName', 'DocumentId'),
    @('goldshop',    'InvoiceLines', 'Title',            'LineId'),
    @('goldshop',    'GoldPartyLedger', 'Description',   'LedgerId')
)

function Test-Persian([string]$s) {
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if ($c -ge 0x0600 -and $c -le 0x06FF) { return $true }
    }
    return $false
}

function Repair-One([string]$s) {
    # رشتهٔ خراب → بایت‌های اصلی UTF-8 (از طریق cp1256) → متن درست
    $bytes = $cp1256.GetBytes($s)
    return $utf8Strict.GetString($bytes)
}

$cn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$cn.Open()

$totalFixed = 0
foreach ($t in $targets) {
    $schema = $t[0]; $table = $t[1]; $col = $t[2]; $key = $t[3]
    $sel = "SELECT [$key], [$col] FROM [$schema].[$table] WHERE [$col] IS NOT NULL"
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $sel
    $rd = $cmd.ExecuteReader()

    $rows = @()
    while ($rd.Read()) {
        $v = $rd.GetValue(1)
        if ($null -eq $v) { continue }
        $s = [string]$v
        if ($s.Length -eq 0) { continue }
        # فقط ردیف‌هایی که نویسهٔ مشکوک (U+0080..U+00FF) دارند بررسی می‌شوند.
        $suspect = $false
        foreach ($ch in $s.ToCharArray()) {
            $c = [int]$ch
            if ($c -ge 128 -and $c -le 255) { $suspect = $true; break }
        }
        if (-not $suspect) { continue }
        try {
            $fixed = Repair-One $s
        } catch {
            continue  # UTF-8 نامعتبر → سالم است یا قابل تعمیر نیست؛ دست نزن
        }
        if (-not (Test-Persian $fixed)) { continue }   # نتیجه باید فارسی باشد
        if ($fixed -eq $s) { continue }
        $rows += ,@($rd.GetValue(0), $s, $fixed)
    }
    $rd.Close()

    if ($rows.Count -eq 0) {
        Write-Log ("[{0}.{1}.{2}] OK — no fixable rows" -f $schema, $table, $col)
        continue
    }

    Write-Log ("[{0}.{1}.{2}] {3} fixable row(s)" -f $schema, $table, $col, $rows.Count)
    foreach ($r in $rows) {
        Write-Log ("    {0} = {1}" -f $r[0], $r[2])
        if ($Apply) {
            $upd = $cn.CreateCommand()
            $upd.CommandText = "UPDATE [$schema].[$table] SET [$col] = @v WHERE [$key] = @k"
            $upd.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@v", $r[2]))) | Out-Null
            $upd.Parameters.Add((New-Object System.Data.SqlClient.SqlParameter("@k", $r[0]))) | Out-Null
            $upd.ExecuteNonQuery() | Out-Null
            $totalFixed++
        }
    }
}
$cn.Close()

if ($Apply) {
    Write-Log ""
    Write-Log "=== Applied: $totalFixed row(s) repaired ==="
} else {
    Write-Log ""
    Write-Log "=== DRY RUN — $totalFixed would be fixed. Re-run with -Apply to commit. ==="
}
if ($null -ne $logOut) { $logOut.Close() }