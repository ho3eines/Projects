# ============================================================
# tools/seed-projects-hermes7.ps1
# Registers the 7 Hermes products in [dbo].[Projects] (v2 registry).
#
# All 7 products point at the HermesMaster database with their own
# SQL schema (the single-DB dev model behind the v2 transport):
#   product → Schema=accounting → scripts under Data/Scripts/accounting/
#
# Run after webapi has started once (it creates the Projects table):
#   powershell -ExecutionPolicy Bypass -File tools/seed-projects-hermes7.ps1
# ============================================================

param(
    [string]$Server = "localhost",
    [string]$Database = "HermesMaster",
    [string]$LoginToken = "hermes-admin"
)

$connStr = "Server=$Server;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;"
$loginTokenHash = ([Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($LoginToken)))).ToLowerInvariant()

$masterConn = "Server=$Server;Database=master;Trusted_Connection=True;TrustServerCertificate=True;"

# The 7 products: Name(FA), app name, ProjectGuid, schema, api key, encryption key (client Encryption.Key)
$projects = @(
    @{ Name = 'حسابداری';      App = 'accounting';    Guid = '8f3c2a11-6b4e-4d9f-a1c7-2e0b9d4f8a31'; Schema = 'accounting'; Key = 'Hermes-Accounting-Handshake-2026-K7mQ2pL9xR4vN8wC'; Icon = '📒'; Url = 'https://localhost:65218/' },
    @{ Name = 'مرکز مدیریت';   App = 'central';       Guid = '1b7e9c44-0d2a-4f18-9e55-6c8a1d3b0f22'; Schema = 'central';    Key = 'Hermes-Central-Handshake-2026-B3tY6hJ1sF5dA0uE';    Icon = '◈'; Url = 'https://localhost:65219/' },
    @{ Name = 'انبار آمل';     App = 'inventory';     Guid = '462cbfaa-c4aa-4248-acd7-44cab2bb982c'; Schema = 'inventory';  Key = 'Hermes-Inventory-Handshake-2026-Q3wE5rT7yU9iO0pA';  Icon = '📦'; Url = 'https://localhost:65224/' },
    @{ Name = 'خزانه‌داری';    App = 'treasury';      Guid = '25ba213c-d564-436a-aba4-7960dc65ca58'; Schema = 'treasury';   Key = 'Hermes-Treasury-Handshake-2026-Z8xC6vB4nM2kL9jH';   Icon = '💰'; Url = 'https://localhost:65226/' },
    @{ Name = 'حقوق و دستمزد'; App = 'payroll';       Guid = 'f02962a5-a4c4-4f42-adae-06b2f91e4b6e'; Schema = 'payroll';    Key = 'Hermes-Payroll-Handshake-2026-F5gH7jK9lM1nB3vC';    Icon = '👥'; Url = 'https://localhost:65228/' },
    @{ Name = 'مدیریت طلافروشی'; App = 'goldshop';    Guid = '8dd13c7b-1fb6-42f4-943a-7cc9c0204afb'; Schema = 'goldshop';   Key = 'Hermes-Goldshop-Handshake-2026-X2dF4gH6jK8lQ1wE';   Icon = '🥇'; Url = 'https://localhost:65230/' },
    @{ Name = 'فروشگاه اینترنتی'; App = 'store';      Guid = '0a9bc93f-8eb3-416c-abaa-666f8181331f'; Schema = 'store';      Key = 'Hermes-Store-Handshake-2026-V7bN3mK9lP5rT2yU';      Icon = '🏪'; Url = 'https://localhost:65232/' }
)

# Make sure HermesMaster exists
$masterConnObj = New-Object System.Data.SqlClient.SqlConnection($masterConn)
$masterConnObj.Open()
$createDb = "IF DB_ID(N'$Database') IS NULL CREATE DATABASE [$Database];"
$cmd = $masterConnObj.CreateCommand(); $cmd.CommandText = $createDb; $cmd.ExecuteNonQuery() | Out-Null
$masterConnObj.Close()

$conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
$conn.Open()

$dbConnStr = "Server=$Server;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;"

foreach ($p in $projects) {
    $apiKey = 'api_key_' + $p.App
    $sql = @"
IF EXISTS (SELECT 1 FROM [dbo].[Projects] WHERE ProjectGuid = '$($p.Guid)')
BEGIN
    UPDATE [dbo].[Projects]
    SET Name = N'$($p.Name)', [Schema] = N'$($p.Schema)',
        LoginTokenHash = N'$loginTokenHash', EncryptionKey = N'$($p.Key)',
        ApiKey = N'$apiKey', IsActive = 1,
        ConnectionString = N'$dbConnStr', DatabaseName = N'$Database',
        DatabaseProvider = N'SqlServer', SessionTimeoutMinutes = 60,
        Description = N'$($p.Name) — Hermes platform', Icon = N'$($p.Icon)',
        ClientUrl = N'$($p.Url)'
    WHERE ProjectGuid = '$($p.Guid)';
END
ELSE
BEGIN
    INSERT INTO [dbo].[Projects]
        (ProjectGuid, Name, [Schema], LoginTokenHash, EncryptionKey, ApiKey,
         SessionTimeoutMinutes, IsActive, ConnectionString, DatabaseName,
         DatabaseProvider, Description, Icon, ClientUrl, CreatedAtUtc)
    VALUES
        ('$($p.Guid)', N'$($p.Name)', N'$($p.Schema)', N'$loginTokenHash', N'$($p.Key)', N'$apiKey',
         60, 1, N'$dbConnStr', N'$Database', N'SqlServer',
         N'$($p.Name) — Hermes platform', N'$($p.Icon)', N'$($p.Url)', GETUTCDATE());
END
"@
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.ExecuteNonQuery() | Out-Null
    Write-Host "upserted: $($p.Name) ($($p.App)) apiKey=$apiKey"
}

$conn.Close()
Write-Host ""
Write-Host "Done. Login token for all projects: '$LoginToken' (loginTokenHash = $loginTokenHash)"
