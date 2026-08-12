using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace HermesApp.Services;

/// <summary>
/// Executes named TSQL scripts against the single <c>HermesMaster</c>
/// database using Dapper — directly from the Blazor Server process.
///
/// This replaces the old <c>webapi</c> + <c>IRequestService</c> transport:
/// no HTTP, no handshake, no AES envelopes, no tokens passed via URL.
/// The schema is the scope guard: each product module only calls scripts of
/// its own schema, and every script is fully qualified to its own schema.
/// </summary>
public sealed class DbService
{
    private readonly IConfiguration _config;
    private readonly ScriptCatalog _catalog;
    private readonly ILogger<DbService> _logger;
    private readonly string _connectionString;

    public DbService(IConfiguration config, ScriptCatalog catalog, ILogger<DbService> logger)
    {
        _config = config;
        _catalog = catalog;
        _logger = logger;
        _connectionString = config.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured.");
    }

    public async Task<IReadOnlyList<T>> QueryAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        var rows = await conn.QueryAsync<T>(new CommandDefinition(sql, parameters, cancellationToken: ct));
        return rows.AsList();
    }

    public async Task<T?> QueryFirstOrDefaultAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        return await conn.QueryFirstOrDefaultAsync<T>(new CommandDefinition(sql, parameters, cancellationToken: ct));
    }

    public async Task<int> ExecuteAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        return await conn.ExecuteAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
    }

    public async Task<object?> ScalarAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        return await conn.ExecuteScalarAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
    }

    /// <summary>Runs every <c>{schema}/_Ensure.sql</c> — creates schemas/tables.</summary>
    public async Task EnsureSchemaAsync(CancellationToken ct = default)
    {
        foreach (var schema in _catalog.Schemas)
        {
            if (_catalog.TryGet(schema, "_Ensure", out var ensure))
            {
                await using var conn = Open();
                await conn.ExecuteAsync(new CommandDefinition(ensure, commandTimeout: 120, cancellationToken: ct));
            }
        }
    }

    /// <summary>Runs every <c>{schema}/_Seed.sql</c> — idempotent seed data.</summary>
    public async Task SeedAsync(CancellationToken ct = default)
    {
        foreach (var schema in _catalog.Schemas)
        {
            if (_catalog.TryGet(schema, "_Seed", out var seed))
            {
                await using var conn = Open();
                await conn.ExecuteAsync(new CommandDefinition(seed, commandTimeout: 120, cancellationToken: ct));
            }
        }
    }

    private SqlConnection Open()
    {
        var conn = new SqlConnection(_connectionString);
        conn.Open();
        return conn;
    }

    private string Resolve(string schema, string scriptName)
    {
        if (!_catalog.TryGet(schema, scriptName, out var sql))
            throw new InvalidOperationException(
                $"Named script '{scriptName}' not found for schema '{schema}'.");

        return sql;
    }
}
