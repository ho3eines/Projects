using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Share;

namespace WebApi.Services;

/// <summary>
/// Seeds the 7 Hermes product projects into [dbo].[Projects] at startup so that
/// `docker compose up` (PRD AC #1) works with no manual step.
///
/// Values mirror tools/seed-projects-hermes7.ps1 and the client appsettings:
///   - EncryptionKey   = the product's SharedKey (client AES-encrypts its login
///                        token with this exact value in appsettings Encryption.Key)
///   - LoginTokenHash  = SHA-256 (lower hex) of the fixed login token "hermes-admin"
///   - ApiKey          = "api_key_{name}"
///   - ConnectionString/DatabaseName = the shared HermesMaster dev database
///
/// Idempotent: upsert by ProjectGuid; a project the operator has already
/// customized (different keys) is left untouched (only missing rows are inserted,
/// existing rows keep their configured credentials).
/// </summary>
public sealed class ProjectSeedInitializer : IHostedService
{
    private readonly string? _cs;
    private readonly HermesProjectsOptions _hermes;
    private readonly ILogger<ProjectSeedInitializer> _log;

    public ProjectSeedInitializer(
        IOptions<ConnectionStringsOptions> cs,
        IOptions<HermesProjectsOptions> hermes,
        ILogger<ProjectSeedInitializer> log)
    {
        _cs = cs.Value.DefaultConnection;
        _hermes = hermes.Value;
        _log = log;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_cs))
        {
            _log.LogWarning("No connection string — skip project seeding");
            return Task.CompletedTask;
        }

        // Run in background so webapi startup does not block on SQL warm-up.
        _ = Task.Run(async () =>
        {
            const int maxAttempts = 12;
            for (var attempt = 1; attempt <= maxAttempts; attempt++)
            {
                try
                {
                    await RunAsync();
                    return;
                }
                catch (Exception ex)
                {
                    if (attempt == maxAttempts)
                    {
                        _log.LogWarning(ex, "Project seeding failed after {Attempts} attempts", maxAttempts);
                        return;
                    }
                    _log.LogInformation("Project seeding attempt {A}/{M} failed: {Msg} — retrying in 5s",
                        attempt, maxAttempts, ex.Message);
                    await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
                }
            }
        }, cancellationToken);
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    private async Task RunAsync()
    {
        var connectionString = new SqlConnectionStringBuilder(_cs)
        {
            InitialCatalog = "HermesMaster"
        }.ConnectionString;

        var loginToken = "hermes-admin";
        var loginTokenHash = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(loginToken))).ToLowerInvariant();

        await using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        foreach (var p in _hermes.Projects)
        {
            if (p.Guid == Guid.Empty || string.IsNullOrWhiteSpace(p.Schema))
                continue;

            var apiKey = "api_key_" + p.Name;
            var clientUrl = string.IsNullOrWhiteSpace(p.ClientUrl)
                ? HermesApps.ForSchema(p.Schema)
                : p.ClientUrl.Trim();
            var affected = await conn.ExecuteAsync(@"
IF NOT EXISTS (SELECT 1 FROM [dbo].[Projects] WHERE ProjectGuid = @Guid)
BEGIN
    INSERT INTO [dbo].[Projects]
        (ProjectGuid, [Name], [Schema], LoginTokenHash, EncryptionKey, ApiKey,
         SessionTimeoutMinutes, IsActive, ConnectionString, DatabaseName,
         DatabaseProvider, AutoBackupEnabled, AutoBackupIntervalMinutes, MaxBackupRetention,
         Description, Icon, ClientUrl, CreatedAtUtc)
    VALUES
        (@Guid, @Name, @Schema, @LoginTokenHash, @EncryptionKey, @ApiKey,
         @TimeoutMinutes, 1, @ConnStr, N'HermesMaster', N'SqlServer',
         1, 1440, 7, N'Hermes platform — auto-seeded', N'◈', @ClientUrl, GETUTCDATE());
END
ELSE IF EXISTS (
    SELECT 1 FROM [dbo].[Projects]
    WHERE ProjectGuid = @Guid AND (ClientUrl IS NULL OR LTRIM(RTRIM(ClientUrl)) = '')
)
BEGIN
    UPDATE [dbo].[Projects] SET ClientUrl = @ClientUrl WHERE ProjectGuid = @Guid;
END",
                new
                {
                    Guid = p.Guid,
                    Name = p.Name,
                    Schema = p.Schema,
                    LoginTokenHash = loginTokenHash,
                    EncryptionKey = p.SharedKey,
                    ApiKey = apiKey,
                    TimeoutMinutes = _hermes.SessionMinutes,
                    ConnStr = connectionString,
                    ClientUrl = clientUrl
                });
            _log.LogInformation("Project seed {Name}: {Action} url={Url}", p.Name, affected == 0 ? "already present" : "upserted", clientUrl);
        }
    }
}
