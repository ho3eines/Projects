$connStr = 'Server=localhost;Database=HermesMaster;Trusted_Connection=True;TrustServerCertificate=True;'
$conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
$conn.Open()

$projects = @(
    @{Name='حسابداری'; Db='AccountingDB'; Desc='سیستم حسابداری مالی'; Url='https://localhost:65218/'},
    @{Name='خزانه‌داری'; Db='TreasuryDB'; Desc='مدیریت خزانه‌داری و صندوق'; Url='https://localhost:65226/'},
    @{Name='انبار'; Db='WarehouseDB'; Desc='مدیریت انبار و موجودی'; Url='https://localhost:65224/'},
    @{Name='اموال'; Db='AssetsDB'; Desc='مدیریت اموال و دارایی‌ها'; Url=''},
    @{Name='کارگزینی و حقوق و دستمزد'; Db='HRDB'; Desc='کارگزینی، حقوق و دستمزد'; Url='https://localhost:65228/'},
    @{Name='فروشگاه'; Db='ShopDB'; Desc='مدیریت فروشگاه'; Url='https://localhost:65232/'},
    @{Name='مدیریت طلافروشی'; Db='GoldShopDB'; Desc='مدیریت طلافروشی و جواهر'; Url='https://localhost:65230/'},
    @{Name='کافی‌شاپ'; Db='CafeDB'; Desc='مدیریت کافی‌شاپ و رستوران'; Url=''}
)

foreach ($p in $projects) {
    $guid = [Guid]::NewGuid()
    $apiKey = 'api_key_' + $p.Db.ToLower() + '_' + ('{0:D3}' -f [int]($guid.GetHashCode() % 1000))
    $dbConnStr = 'Server=localhost;Database=' + $p.Db + ';Trusted_Connection=True;TrustServerCertificate=True'
    $sql = @"
    INSERT INTO dbo.Projects (ProjectGuid, Name, [Schema], LoginTokenHash, EncryptionKey, ApiKey, SessionTimeoutMinutes, IsActive, ConnectionString, DatabaseName, DatabaseProvider, AutoBackupEnabled, AutoBackupIntervalMinutes, AutoBackupTimeUtc, MaxBackupRetention, Description, ClientUrl, CreatedAtUtc)
    VALUES ('$guid', N'$($p.Name)', N'dbo', N'token_hash', N'enc_key', '$apiKey', 10, 1, '$dbConnStr', N'$($p.Db)', N'SqlServer', 1, 1440, '02:00:00', 7, N'$($p.Desc)', N'$($p.Url)', GETUTCDATE());
"@
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.ExecuteNonQuery() | Out-Null
}

$cmd2 = $conn.CreateCommand()
$cmd2.CommandText = 'SELECT Name, ProjectGuid FROM dbo.Projects ORDER BY Name'
$reader = $cmd2.ExecuteReader()
while($reader.Read()) { Write-Host "$($reader['Name']) | $($reader['ProjectGuid'])" }
$conn.Close()