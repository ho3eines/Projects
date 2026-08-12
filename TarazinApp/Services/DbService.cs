using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace TarazinApp.Services;

/// <summary>
/// Executes named TSQL scripts against the single <c>TarazinMaster</c>
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
    private readonly AuditService _audit;
    private readonly UserSession _session;
    private readonly ILogger<DbService> _logger;
    private readonly string _connectionString;

    public DbService(IConfiguration config, ScriptCatalog catalog, AuditService audit,
        UserSession session, ILogger<DbService> logger)
    {
        _config = config;
        _catalog = catalog;
        _audit = audit;
        _session = session;
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

    /// <summary>
    /// Executes a mutating script and **auto-records an audit row** for it
    /// (PRD §5 / ADR-002: every mutating operation is hash-chained in
    /// [central].[AuditLog]). Audit failures never break the business call.
    /// </summary>
    public async Task<int> ExecuteAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        try
        {
            var affected = await conn.ExecuteAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
            await _audit.RecordAsync(schema, scriptName, _session.UserName, "Success", null, ct);
            return affected;
        }
        catch (Exception ex)
        {
            await _audit.RecordAsync(schema, scriptName, _session.UserName, "Error", ex.Message, ct);
            throw;
        }
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
