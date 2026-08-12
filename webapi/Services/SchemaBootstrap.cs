using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public sealed class SchemaBootstrap : IHostedService
{
    private readonly ISystemQueryExecutor _executor;
    private readonly string? _cs;
    private readonly string _adminPassword;
    private readonly ILogger<SchemaBootstrap> _log;

    public SchemaBootstrap(
        ISystemQueryExecutor executor,
        IOptions<ConnectionStringsOptions> cs,
        IOptions<HermesProjectsOptions> hermes,
        ILogger<SchemaBootstrap> log)
    {
        _executor = executor;
        _cs = cs.Value.DefaultConnection;
        _adminPassword = hermes.Value.BootstrapAdminPassword;
        _log = log;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_cs))
        {
            _log.LogWarning("No connection string — skip schema bootstrap");
            return;
        }

        try
        {
            await _executor.ExecuteAsync("_Ensure", null, "central");
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Could not run central/_Ensure — DB may be offline");
            return;
        }

        try
        {
            await using var conn = new SqlConnection(_cs);
            await conn.OpenAsync(cancellationToken);
            var count = await conn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [central].[Users] WHERE IsDeleted = 0");
            if (count == 0)
            {
                var hash = PasswordHasher.Hash(_adminPassword);
                await conn.ExecuteAsync(@"
INSERT INTO [central].[Users] (Username, PasswordHash, DisplayName, Role, IsActive, CreatedBy)
VALUES (N'admin', @hash, N'Administrator', N'Admin', 1, N'seed');",
                    new { hash });
                _log.LogWarning("Seeded admin user. Change Hermes:BootstrapAdminPassword after first login.");
            }
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Could not seed admin user");
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
