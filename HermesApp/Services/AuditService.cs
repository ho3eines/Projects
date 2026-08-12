using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HermesApp.Models;

namespace HermesApp.Services;

/// <summary>
/// Tamper-evident audit trail (hash chain) written to <c>[central].[AuditLog]</c>.
/// Every mutating script execution is recorded; the hash chain makes past rows
/// detectable if they were edited.
/// </summary>
public sealed class AuditService
{
    private readonly DbService _db;
    private readonly ILogger<AuditService> _logger;

    public AuditService(DbService db, ILogger<AuditService> logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <summary>
    /// Records one script execution. <paramref name="userName"/> is the signed-in
    /// user (empty when anonymous/startup). Failures are logged, never thrown,
    /// so auditing can never break the business call it wraps.
    /// </summary>
    public async Task RecordAsync(
        string schema,
        string scriptName,
        object? parameters = null,
        string? userName = null,
        bool isExec = true,
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
                Parameters = parameters,
                UserName = userName,
                Outcome = outcome,
                Error = error,
                CreatedAt = DateTime.UtcNow
            });
            var rowHash = Sha256(payload);

            await _db.ExecuteAsync("central", "AuditInsert", new
            {
                PrevHash = prevHash,
                RowHash = rowHash,
                SchemaName = schema,
                ScriptName = scriptName,
                UserName = userName,
                Outcome = outcome,
                Error = error
            }, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Audit write failed for {Schema}/{Script}", schema, scriptName);
        }
    }

    private async Task<string> LastRowHashAsync(CancellationToken ct)
    {
        var last = await _db.QueryFirstOrDefaultAsync<AuditRow>(
            "central", "AuditLastRowHash", null, ct);
        return last?.RowHash ?? Sha256("genesis");
    }

    private static string Sha256(string text)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(text));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
