using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Tarazin.Models;

namespace Tarazin.Data;

/// <summary>
/// Tenant-owned audit records written to <c>[central].[AuditLog]</c>.
/// The current rows retain predecessor metadata, but are not yet a correct
/// tamper-evident chain: <c>RowHash</c> omits <c>PrevHash</c>, and predecessor
/// lookup/insertion are not serialized. ADR-002 records this release gate.
///
/// <c>CompanyId</c> is deliberately <c>NULL</c> for system-level operations
/// (startup migrations, seed, access syncs) that run with no tenant context.
/// Those rows must NEVER be backfilled to a company — see
/// docs/adr/ADR-004-auditlog-null-company.md.
///
/// Self-contained on purpose: it opens its own connection and resolves its own
/// scripts so it never depends on <see cref="DbService"/> — that would create a
/// circular dependency and recursion, because <see cref="DbService"/> auto-audits
/// every execute through this service.
/// </summary>
public sealed class AuditService
{
    private readonly ISqlConnectionProvider _connectionProvider;
    private readonly ScriptCatalog _catalog;
    private readonly ILogger<AuditService> _logger;

    public AuditService(ISqlConnectionProvider connectionProvider, ScriptCatalog catalog, ILogger<AuditService> logger)
    {
        _connectionProvider = connectionProvider;
        _catalog = catalog;
        _logger = logger;
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
        int? activeCompanyId = null,
        string outcome = "Success",
        string? error = null,
        CancellationToken ct = default)
    {
        try
        {
            var prevHash = await LastRowHashAsync(activeCompanyId, ct);
            var payload = JsonSerializer.Serialize(new
            {
                SchemaName = schema,
                ScriptName = scriptName,
                UserName = userName,
                CompanyId = activeCompanyId,
                Outcome = outcome,
                Error = error,
                CreatedAt = DateTime.UtcNow
            });
            var rowHash = Sha256(payload);

            if (!_catalog.TryGet("central", "AuditInsert", out var sql))
                throw new InvalidOperationException("Named script 'central/AuditInsert' not found.");

            await using var conn = await OpenConnectionAsync(activeCompanyId, ct);
            await conn.ExecuteAsync(new CommandDefinition(sql, new
            {
                CompanyId = activeCompanyId,
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
            _logger.LogError("Audit write failed for {Schema}/{Script} ({ErrorType})",
                schema, scriptName, ex.GetType().Name);
        }
    }

    private async Task<string> LastRowHashAsync(int? activeCompanyId, CancellationToken ct)
    {
        if (!_catalog.TryGet("central", "AuditLastRowHash", out var sql))
            return Sha256("genesis");

        await using var conn = await OpenConnectionAsync(activeCompanyId, ct);
        var last = await conn.QueryFirstOrDefaultAsync<AuditRow>(
            new CommandDefinition(sql, new { CompanyId = activeCompanyId }, cancellationToken: ct));
        return last?.RowHash ?? Sha256("genesis");
    }

    private async ValueTask<SqlConnection> OpenConnectionAsync(int? activeCompanyId, CancellationToken ct)
    {
        var connection = await _connectionProvider.OpenConnectionAsync(ct);
        try
        {
            await connection.ExecuteAsync(new CommandDefinition(
                "EXEC sys.sp_set_session_context @key=N'TarazinCompanyId', @value=@CompanyId;",
                new { CompanyId = activeCompanyId }, cancellationToken: ct));
            return connection;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    private static string Sha256(string text)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(text));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
