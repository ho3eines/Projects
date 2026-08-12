using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using System.Data;
using System.Text.Json;

namespace WebApi.Services;

public interface ISystemQueryExecutor
{
    Task<List<dynamic>> QueryAsync(string scriptName, object? parameters, string? schema);
    Task<int> ExecuteAsync(string scriptName, object? parameters, string? schema);
    Task<object?> ScalarAsync(string scriptName, object? parameters, string? schema);
}

public class SystemQueryExecutor : ISystemQueryExecutor
{
    private readonly string _connectionString;
    private readonly string _scriptsRoot;
    private readonly ILogger<SystemQueryExecutor> _logger;

    public SystemQueryExecutor(IOptions<ConnectionStringsOptions> options, IWebHostEnvironment env, ILogger<SystemQueryExecutor> logger)
    {
        _connectionString = options.Value.DefaultConnection!;
        _scriptsRoot = Path.Combine(env.ContentRootPath, "Data", "Scripts");
        _logger = logger;
    }

    private string ResolveScriptPath(string scriptName, string? schema)
    {
        if (string.IsNullOrWhiteSpace(scriptName))
            throw new FileNotFoundException($"TSQL script not found: {scriptName}");

        // Schema-scoped resolution only: a script always lives under its own
        // schema folder (Data/Scripts/{schema}/{name}.sql). The caller (session /
        // outbox route / bootstrap) always supplies the owning schema, so a client
        // can never reach another product's scripts by passing a path or dot-name —
        // enforcing the ADR-001 schema lock. ".." is neutralized by a containment
        // check after GetFullPath normalizes the candidate.
        var schemaDir = string.IsNullOrWhiteSpace(schema) ? "dbo" : schema;
        var baseDir = Path.GetFullPath(Path.Combine(_scriptsRoot, schemaDir));
        var normalized = scriptName.Replace('\\', '/').Replace(".sql", "", StringComparison.OrdinalIgnoreCase);
        var candidate = Path.GetFullPath(Path.Combine(baseDir, normalized + ".sql"));

        if (!candidate.StartsWith(baseDir + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            && !string.Equals(candidate, baseDir, StringComparison.OrdinalIgnoreCase))
        {
            throw new FileNotFoundException($"TSQL script not found: {scriptName}");
        }
        if (!File.Exists(candidate))
            throw new FileNotFoundException($"TSQL script not found: {scriptName}", candidate);
        return candidate;
    }

    private async Task<IDbConnection> OpenConnectionAsync()
    {
        var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        return conn;
    }

    private static DynamicParameters BuildParameters(object? parameters)
    {
        var dp = new DynamicParameters();
        if (parameters is JsonElement je && je.ValueKind == JsonValueKind.Object)
        {
            foreach (var prop in je.EnumerateObject())
                dp.Add(prop.Name, SqlParameterValueNormalizer.Normalize(prop.Value));
        }
        else if (parameters is not null)
        {
            dp.AddDynamicParams(parameters);
        }
        return dp;
    }

    public async Task<List<dynamic>> QueryAsync(string scriptName, object? parameters, string? schema)
    {
        var path = ResolveScriptPath(scriptName, schema);
        var sql = await File.ReadAllTextAsync(path);
        var dp = BuildParameters(parameters);
        using var conn = await OpenConnectionAsync();
        var rows = await conn.QueryAsync(sql, dp);
        return rows.ToList();
    }

    public async Task<int> ExecuteAsync(string scriptName, object? parameters, string? schema)
    {
        var path = ResolveScriptPath(scriptName, schema);
        var sql = await File.ReadAllTextAsync(path);
        var dp = BuildParameters(parameters);
        using var conn = await OpenConnectionAsync();
        return await conn.ExecuteAsync(sql, dp);
    }

    public async Task<object?> ScalarAsync(string scriptName, object? parameters, string? schema)
    {
        var path = ResolveScriptPath(scriptName, schema);
        var sql = await File.ReadAllTextAsync(path);
        var dp = BuildParameters(parameters);
        using var conn = await OpenConnectionAsync();
        return await conn.ExecuteScalarAsync(sql, dp);
    }
}

public class ConnectionStringsOptions
{
    public string? DefaultConnection { get; set; }
}