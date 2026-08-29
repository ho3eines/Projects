# check-stale-build.ps1 — Windows-native equivalent of check-stale-build.sh
$ErrorActionPreference = 'Stop'
$ui   = 'Tarazin.Ui/bin/Debug/net8.0'
$web  = 'Tarazin.Web/bin/Debug/net8.0'
$stale = @()

if (-not (Test-Path $ui) -or -not (Test-Path $web)) {
    Write-Output "ERROR: build output missing. Run 'dotnet build Tarazin.Web/Tarazin.Web.csproj' first."
    exit 2
}

Write-Output '=== Stale-Build Guard ==='

# 1) Every Ui-built DLL copied into Web/bin must not be older than its Ui/bin original.
Get-ChildItem -Path (Join-Path $ui '*.dll') | ForEach-Object {
    $name = $_.Name
    $wf = Join-Path $web $name
    if (Test-Path $wf) {
        if ((Get-Item $wf).LastWriteTimeUtc -lt $_.LastWriteTimeUtc) {
            Write-Output ("STALE: {0} - Tarazin.Web/bin copy is OLDER than Tarazin.Ui/bin." -f $name)
            $stale += $name
        }
    }
}

# 2) Tarazin.Ui.dll must not be older than its newest source file.
$newest = Get-ChildItem 'Tarazin.Ui' -Recurse -Include '*.cs', '*.razor' -File |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$uiDll = Join-Path $ui 'Tarazin.Ui.dll'
if ($newest -and (Test-Path $uiDll) -and ((Get-Item $uiDll).LastWriteTimeUtc -lt $newest.LastWriteTimeUtc)) {
    Write-Output ("STALE: Tarazin.Ui.dll is OLDER than newest source ({0})." -f $newest.Name)
    $stale += 'Tarazin.Ui.dll'
}

Write-Output ''
if ($stale.Count -eq 0) {
    Write-Output 'FRESH: Tarazin.Web/bin matches Tarazin.Ui/bin - safe to restart the server.'
    exit 0
}
Write-Output 'FAILED: stale build detected - do NOT restart the server until rebuilt.'
exit 1