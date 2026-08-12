namespace Hermes.ContractTests;

/// <summary>
/// xUnit fixture: connects to SQL Server (HERMES_TEST_CONNECTION or the
/// docker compose default) and ensures all schemas are created and seeded
/// (runs every _Ensure.sql then every _Seed.sql, like webapi's SchemaBootstrap).
/// Tests are skipped when the database is unreachable.
/// </summary>
public sealed class TestDatabase : IAsyncLifetime
{
    public string ConnectionString { get; }
    public string RepoRoot { get; }
    public bool Available { get; private set; }
    public SqlRunner Sql { get; }

    public static readonly string[] Schemas =
        { "central", "accounting", "inventory", "treasury", "payroll", "goldshop", "store" };

    public TestDatabase()
    {
        ConnectionString = Environment.GetEnvironmentVariable("HERMES_TEST_CONNECTION")
            ?? "Server=localhost,1433;Database=HermesMaster;User Id=sa;Password=Hermes!Master2026;TrustServerCertificate=True;Encrypt=False";
        RepoRoot = Environment.GetEnvironmentVariable("HERMES_REPO_ROOT")
            ?? FindRepoRoot(AppContext.BaseDirectory);
        Sql = new SqlRunner(ConnectionString);
    }

    public async Task InitializeAsync()
    {
        if (!await Sql.CanConnectAsync())
        {
            Available = false;
            return;
        }

        Available = true;
        foreach (var name in new[] { "_Ensure", "_Seed" })
        {
            foreach (var schema in Schemas)
            {
                var path = Path.Combine(RepoRoot, "webapi", "Data", "Scripts", schema, name + ".sql");
                if (!File.Exists(path))
                    continue;
                var script = await File.ReadAllTextAsync(path);
                await Sql.ExecuteAsync(script);
            }
        }
    }

    public Task DisposeAsync() => Task.CompletedTask;

    public string ScriptPath(string schema, string scriptName)
        => Path.Combine(RepoRoot, "webapi", "Data", "Scripts", schema, scriptName + ".sql");

    public async Task<string> ReadScriptAsync(string schema, string scriptName)
        => await File.ReadAllTextAsync(ScriptPath(schema, scriptName));

    private static string FindRepoRoot(string start)
    {
        var dir = new DirectoryInfo(start);
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "webapi", "Data", "contracts.manifest.json")))
                return dir.FullName;
            dir = dir.Parent;
        }
        throw new InvalidOperationException("Repository root not found — set HERMES_REPO_ROOT");
    }
}
