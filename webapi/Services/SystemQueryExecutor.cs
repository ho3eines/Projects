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
        var normalized = scriptName.Replace('\\', '/').Replace('.', '/');
        string fullPath;

        var parts = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2)
        {
            fullPath = Path.Combine(_scriptsRoot, string.Join('/', parts) + ".sql");
            if (File.Exists(fullPath)) return fullPath;
        }
        if (!string.IsNullOrEmpty(schema))
        {
            fullPath = Path.Combine(_scriptsRoot, schema, scriptName + ".sql");
            if (File.Exists(fullPath)) return fullPath;
        }
        fullPath = Path.Combine(_scriptsRoot, scriptName + ".sql");
        if (!File.Exists(fullPath))
            throw new FileNotFoundException($"TSQL script not found: {scriptName}", fullPath);
        return fullPath;
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
            {
                if (prop.Value.ValueKind == JsonValueKind.Null) { dp.Add(prop.Name, null); continue; }
                switch (prop.Value.ValueKind)
                {
                    case JsonValueKind.String: dp.Add(prop.Name, prop.Value.GetString()); break;
                    case JsonValueKind.Number:
                        if (prop.Value.TryGetInt64(out var l)) dp.Add(prop.Name, l);
                        else if (prop.Value.TryGetDouble(out var d)) dp.Add(prop.Name, d);
                        else dp.Add(prop.Name, prop.Value.GetRawText());
                        break;
                    case JsonValueKind.True: case JsonValueKind.False: dp.Add(prop.Name, prop.Value.GetBoolean()); break;
                    default: dp.Add(prop.Name, prop.Value.GetRawText()); break;
                }
            }
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