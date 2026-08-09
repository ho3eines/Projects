using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using System.Data;
using System.Text.Json;

namespace WebApi.Services;

/// <summary>
/// Executes named TSQL files from Data/Scripts/{schema}/{name}.sql
/// against SQL Server. All projects share this one executor.
/// </summary>
public interface ISystemQueryExecutor
{
    Task<List<T>> QueryAsync<T>(string scriptName, object? parameters, string? schema);
    Task<int> ExecuteAsync(string scriptName, object? parameters, string? schema);
    Task<object?> ScalarAsync(string scriptName, object? parameters, string? schema);
}

public class SystemQueryExecutor : ISystemQueryExecutor
{
    private readonly string _connectionString;
    private readonly string _scriptsRoot;
    private readonly ILogger<SystemQueryExecutor> _logger;

    public SystemQueryExecutor(IOptions<ConnectionStringsOptions> options,
                               IWebHostEnvironment env,
                               ILogger<SystemQueryExecutor> logger)
    {
        _connectionString = options.Value.DefaultConnection!;
        // Scripts live at webapi/Data/Scripts/
        _scriptsRoot = Path.Combine(env.ContentRootPath, "Data", "Scripts");
        _logger = logger;
    }

    private string ResolveScriptPath(string scriptName, string? schema)
    {
        // Support: "DailyDocuments" | "accounting/DailyDocuments" | "accounting.DailyDocuments"
        var normalized = scriptName.Replace('\\', '/').Replace('.', '/');
        var segments = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries);

        string fullPath;
        if (segments.Length >= 2 && Directory.Exists(Path.Combine(_scriptsRoot, segments[0])))
        {
            fullPath = Path.Combine(_scriptsRoot, string.Join('/', segments) + ".sql");
        }
        else if (!string.IsNullOrEmpty(schema))
        {
            fullPath = Path.Combine(_scriptsRoot, schema, scriptName + ".sql");
        }
        else
        {
            fullPath = Path.Combine(_scriptsRoot, scriptName + ".sql");
        }

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

    private static void ApplyParameters(DynamicParameters dp, JsonElement? parameters)
    {
        if (parameters is null || parameters.Value.ValueKind != JsonValueKind.Object)
            return;

        foreach (var prop in parameters.Value.EnumerateObject())
        {
            var name = prop.Name;

            if (prop.Value.ValueKind == JsonValueKind.Null)
            {
                dp.Add(name, null);
                continue;
            }

            switch (prop.Value.ValueKind)
            {
                case JsonValueKind.String:
                    dp.Add(name, prop.Value.GetString());
                    break;
                case JsonValueKind.Number:
                    if (prop.Value.TryGetInt64(out var l)) dp.Add(name, l);
                    else if (prop.Value.TryGetDouble(out var d)) dp.Add(name, d);
                    else dp.Add(name, prop.Value.GetRawText());
                    break;
                case JsonValueKind.True:
                case JsonValueKind.False:
                    dp.Add(name, prop.Value.GetBoolean());
                    break;
                default:
                    dp.Add(name, prop.Value.GetRawText());
                    break;
            }
        }
    }

    public async Task<List<T>> QueryAsync<T>(string scriptName, object? parameters, string? schema)
    {
        var path = ResolveScriptPath(scriptName, schema);
        var sql = await File.ReadAllTextAsync(path);

        var dp = new DynamicParameters();
        if (parameters is JsonElement je)
            ApplyParameters(dp, je);
        else if (parameters is not null)
            dp.AddDynamicParams(parameters);

        using var conn = await OpenConnectionAsync();
        var rows = await conn.QueryAsync<T>(sql, dp);
        return rows.AsList();
    }

    public async Task<int> ExecuteAsync(string scriptName, object? parameters, string? schema)
    {
        var path = ResolveScriptPath(scriptName, schema);
        var sql = await File.ReadAllTextAsync(path);

        var dp = new DynamicParameters();
        if (parameters is JsonElement je)
            ApplyParameters(dp, je);
        else if (parameters is not null)
            dp.AddDynamicParams(parameters);

        using var conn = await OpenConnectionAsync();
        return await conn.ExecuteAsync(sql, dp);
    }

    public async Task<object?> ScalarAsync(string scriptName, object? parameters, string? schema)
    {
        var path = ResolveScriptPath(scriptName, schema);
        var sql = await File.ReadAllTextAsync(path);

        var dp = new DynamicParameters();
        if (parameters is JsonElement je)
            ApplyParameters(dp, je);
        else if (parameters is not null)
            dp.AddDynamicParams(parameters);

        using var conn = await OpenConnectionAsync();
        return await conn.ExecuteScalarAsync(sql, dp);
    }
}

public class ConnectionStringsOptions
{
    public string? DefaultConnection { get; set; }
}