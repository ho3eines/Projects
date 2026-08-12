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

        // Run synchronously during host startup so ASP.NET Core does not begin
        // accepting requests until every product schema has been created.  This
        // closes the first-request race where central/accounting tables were
        // still missing and the client got "Invalid object name ...".
        //
        // Retry so `docker compose up` survives the SQL Server warm-up window.
        const int maxAttempts = 12;
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                await RunAllAsync(cancellationToken);
                Completed = true;
                return;
            }
            catch (Exception ex)
            {
                if (attempt == maxAttempts)
                {
                    LastError = ex;
                    _log.LogWarning(ex, "Schema bootstrap failed after {Attempts} attempts", maxAttempts);
                    return;
                }
                _log.LogInformation("Schema bootstrap attempt {Attempt}/{Max} failed: {Message} — retrying in 5s",
                    attempt, maxAttempts, ex.Message);
                await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
            }
        }
    }

    /// <summary>True once all product _Ensure/_Seed scripts have finished.</summary>
    public bool Completed { get; private set; }

    /// <summary>Populated when bootstrap exhausts its retries; null otherwise.</summary>
    public Exception? LastError { get; private set; }

    /// <summary>
    /// Best-effort check that the core tables reported in startup 500s exist.
    /// The health check uses this so the API stays unready if a previous run
    /// partially failed or if the database was reset while the app was running.
    /// </summary>
    public async Task<bool> CoreTablesExistAsync(CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_cs))
            return false;

        try
        {
            await using var conn = new SqlConnection(_cs);
            await conn.OpenAsync(cancellationToken);
            var missing = await conn.QuerySingleAsync<int>(@"
SELECT COUNT(*)
FROM (VALUES
    (N'central', N'News'),
    (N'accounting', N'Documents')
) AS v(SchemaName, TableName)
WHERE NOT EXISTS (
    SELECT 1
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = v.SchemaName AND t.name = v.TableName);");
            return missing == 0;
        }
        catch (Exception ex)
        {
            _log.LogDebug(ex, "Core table existence check failed");
            return false;
        }
    }

    private async Task RunAllAsync(CancellationToken cancellationToken)
    {
        // _Ensure scripts MUST succeed — they create schemas and tables that
        // every request depends on.  If any of them fails the exception
        // propagates to StartAsync's retry loop (fix: previously TryScript
        // swallowed all errors, so the retry loop never fired and tables
        // like accounting.Documents were silently missing → 500 on first
        // query).
        await EnsureScript("_Ensure", "central");

        foreach (var project in _projects.AllActive())
        {
            if (string.Equals(project.Schema, "central", StringComparison.OrdinalIgnoreCase))
                continue;
            await EnsureScript("_Ensure", project.Schema);
        }

        await UpsertAdminAsync(cancellationToken);

        // _Seed is best-effort: a seed failure should not block startup or
        // trigger a full retry (the data may already exist from a previous
        // run, and the operator can re-seed manually).
        await TryScript("_Seed", "central");
        foreach (var project in _projects.AllActive())
        {
            if (string.Equals(project.Schema, "central", StringComparison.OrdinalIgnoreCase))
                continue;
            await TryScript("_Seed", project.Schema);
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    /// <summary>
    /// Runs an _Ensure script and lets failures propagate so the caller's
    /// retry loop can recover (e.g. SQL Server still warming up during
    /// docker compose up).  FileNotFoundException is still swallowed — a
    /// product that ships without an _Ensure.sql simply has nothing to DDL.
    /// </summary>
    private async Task EnsureScript(string name, string schema)
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
        // All other exceptions (SqlException, connectivity, DDL errors) propagate
        // to RunAllAsync → StartAsync retry loop.
    }

    /// <summary>
    /// Runs a non-critical script (e.g. _Seed).  Failures are logged but do
    /// not abort startup.
    /// </summary>
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
