using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Tarazin.Models;

namespace Tarazin.Data;

/// <summary>
/// Tamper-evident audit trail (hash chain) written to <c>[central].[AuditLog]</c>.
///
/// Self-contained on purpose: it opens its own connection and resolves its own
/// scripts so it never depends on <see cref="DbService"/> — that would create a
/// circular dependency and recursion, because <see cref="DbService"/> auto-audits
/// every execute through this service.
/// </summary>
public sealed class AuditService
{
    private readonly string _connectionString;
    private readonly ScriptCatalog _catalog;
    private readonly ILogger<AuditService> _logger;

    public AuditService(IConfiguration config, ScriptCatalog catalog, ILogger<AuditService> logger)
    {
        _catalog = catalog;
        _logger = logger;
        // همان نقطهٔ واحد خواندن رشتهٔ اتصال که DbService استفاده می‌کند.
        _connectionString = TarazinConnection.Resolve(config);
    }

    /// <summary>
    /// Records one script execution. <paramref name="userName"/> is the signed-in
    /// user (empty when anonymous/startup). Failures are logged, never thrown,
    /// so auditing can never break the business call it wraps.
    ///
    /// Parameters are deliberately NOT stored (they may contain sensitive data
    /// such as password hashes) — only schema/script/user/outcome/error.
    /// </summary>
    public async Task RecordAsync(
        string schema,
        string scriptName,
        string? userName = null,
        string outcome = "Success",
        string? error = null,
        CancellationToken ct = default)
    {
        try
        {
            var prevHash = await LastRowHashAsync(ct);
            var payload = JsonSerializer.Serialize(new
            {
                SchemaName = schema,
                ScriptName = scriptName,
                UserName = userName,
                Outcome = outcome,
                Error = error,
                CreatedAt = DateTime.UtcNow
            });
            var rowHash = Sha256(payload);

            if (!_catalog.TryGet("central", "AuditInsert", out var sql))
                throw new InvalidOperationException("Named script 'central/AuditInsert' not found.");

            await using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync(ct);
            await conn.ExecuteAsync(new CommandDefinition(sql, new
            {
                PrevHash = prevHash,
                RowHash = rowHash,
                SchemaName = schema,
                ScriptName = scriptName,
                UserName = userName,
                Outcome = outcome,
                Error = error
            }, cancellationToken: ct));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Audit write failed for {Schema}/{Script}", schema, scriptName);
        }
    }

    private async Task<string> LastRowHashAsync(CancellationToken ct)
    {
        if (!_catalog.TryGet("central", "AuditLastRowHash", out var sql))
            return Sha256("genesis");

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        var last = await conn.QueryFirstOrDefaultAsync<AuditRow>(
            new CommandDefinition(sql, cancellationToken: ct));
        return last?.RowHash ?? Sha256("genesis");
    }

    private static string Sha256(string text)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(text));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
