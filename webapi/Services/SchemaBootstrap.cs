using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public sealed class SchemaBootstrap : IHostedService
{
    private readonly ISystemQueryExecutor _executor;
    private readonly IProjectCatalog _projects;
    private readonly string? _cs;
    private readonly string _adminPassword;
    private readonly ILogger<SchemaBootstrap> _log;

    public SchemaBootstrap(
        ISystemQueryExecutor executor,
        IProjectCatalog projects,
        IOptions<ConnectionStringsOptions> cs,
        IOptions<HermesProjectsOptions> hermes,
        ILogger<SchemaBootstrap> log)
    {
        _executor = executor;
        _projects = projects;
        _cs = cs.Value.DefaultConnection;
        _adminPassword = string.IsNullOrWhiteSpace(hermes.Value.BootstrapAdminPassword)
            ? "admin"
            : hermes.Value.BootstrapAdminPassword;
        _log = log;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_cs))
        {
            _log.LogWarning("No connection string — skip schema bootstrap");
            return;
        }

        // Retry so `docker compose up` survives the SQL Server warm-up window.
        const int maxAttempts = 12;
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                await RunAllAsync(cancellationToken);
                return;
            }
            catch (Exception ex)
            {
                if (attempt == maxAttempts)
                {
                    _log.LogWarning(ex, "Schema bootstrap failed after {Attempts} attempts", maxAttempts);
                    return;
                }
                _log.LogInformation("Schema bootstrap attempt {Attempt}/{Max} failed: {Message} — retrying in 5s",
                    attempt, maxAttempts, ex.Message);
                await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
            }
        }
    }

    private async Task RunAllAsync(CancellationToken cancellationToken)
    {
        await TryScript("_Ensure", "central");

        foreach (var project in _projects.AllActive())
        {
            if (string.Equals(project.Schema, "central", StringComparison.OrdinalIgnoreCase))
                continue;
            await TryScript("_Ensure", project.Schema);
        }

        await UpsertAdminAsync(cancellationToken);

        await TryScript("_Seed", "central");
        foreach (var project in _projects.AllActive())
        {
            if (string.Equals(project.Schema, "central", StringComparison.OrdinalIgnoreCase))
                continue;
            await TryScript("_Seed", project.Schema);
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    private async Task TryScript(string name, string schema)
    {
        try
        {
            await _executor.ExecuteAsync(name, null, schema);
            _log.LogInformation("Ran {Schema}/{Name}", schema, name);
        }
        catch (FileNotFoundException)
        {
            _log.LogDebug("No {Schema}/{Name}.sql — skip", schema, name);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Could not run {Schema}/{Name}", schema, name);
        }
    }

    private async Task UpsertAdminAsync(CancellationToken cancellationToken)
    {
        try
        {
            await using var conn = new SqlConnection(_cs);
            await conn.OpenAsync(cancellationToken);
            var hash = PasswordHasher.Hash(_adminPassword);
            await conn.ExecuteAsync(@"
IF EXISTS (SELECT 1 FROM [central].[Users] WHERE Username = N'admin')
    UPDATE [central].[Users]
    SET PasswordHash = @hash, IsActive = 1, IsDeleted = 0, DisplayName = N'Administrator', Role = N'Admin'
    WHERE Username = N'admin';
ELSE
    INSERT INTO [central].[Users] (Username, PasswordHash, DisplayName, Role, IsActive, CreatedBy)
    VALUES (N'admin', @hash, N'Administrator', N'Admin', 1, N'seed');",
                new { hash });
            _log.LogInformation("Test login ready: admin / {Password}", _adminPassword);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Could not upsert admin user");
        }
    }
}
