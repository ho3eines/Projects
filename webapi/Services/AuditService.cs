using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public sealed class AuditEntry
{
    public string SchemaName { get; set; } = "";
    public string ScriptName { get; set; } = "";
    public string? Parameters { get; set; }
    public string? UserTokenId { get; set; }
    public string? RequestId { get; set; }
    public string Outcome { get; set; } = "Success";
    public string? Error { get; set; }
}

public interface IAuditService
{
    Task LogAsync(AuditEntry entry);
}

/// <summary>
/// Tamper-evident audit log (PRD §5, ADR-002).
/// Every mutating (IsExec) call is written to [central].[AuditLog] with a
/// SHA-256 hash chain: each row's RowHash includes the previous row's hash.
/// A single process-wide gate serializes the read-hash-insert so the chain
/// cannot fork under concurrency.
/// </summary>
public sealed class AuditService : IAuditService
{
    private static readonly SemaphoreSlim Gate = new(1, 1);
    private readonly string? _cs;
    private readonly ILogger<AuditService> _logger;

    public AuditService(IOptions<ConnectionStringsOptions> options, ILogger<AuditService> logger)
    {
        _cs = options.Value.DefaultConnection;
        _logger = logger;
    }

    public async Task LogAsync(AuditEntry entry)
    {
        if (string.IsNullOrWhiteSpace(_cs))
            return;

        try
        {
            await Gate.WaitAsync();
            try
            {
                await using var conn = new SqlConnection(_cs);
                await conn.OpenAsync();

                var prev = await conn.ExecuteScalarAsync<string>(
                    "SELECT TOP 1 RowHash FROM [central].[AuditLog] ORDER BY AuditId DESC");

                var now = DateTime.UtcNow;
                var payload = string.Join('\u001F',
                    entry.SchemaName, entry.ScriptName,
                    entry.Parameters ?? "", entry.UserTokenId ?? "",
                    entry.RequestId ?? "", entry.Outcome, entry.Error ?? "",
                    now.Ticks.ToString());

                var rowHash = HexSha256((prev ?? "") + '\u001E' + payload);

                await conn.ExecuteAsync(@"
INSERT INTO [central].[AuditLog]
    (PrevHash, RowHash, SchemaName, ScriptName, Parameters, UserTokenId, RequestId, Outcome, Error, CreatedAt)
VALUES
    (@prev, @row, @schema, @script, @prms, @user, @req, @outcome, @err, @now);",
                    new
                    {
                        prev = prev ?? "",
                        row = rowHash,
                        schema = entry.SchemaName,
                        script = entry.ScriptName,
                        prms = Truncate(entry.Parameters, 8000),
                        user = entry.UserTokenId,
                        req = entry.RequestId,
                        outcome = entry.Outcome,
                        err = Truncate(entry.Error, 4000),
                        now
                    }, commandTimeout: 30);
            }
            finally
            {
                Gate.Release();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Audit write failed");
        }
    }

    private static string HexSha256(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes);
    }

    private static string? Truncate(string? value, int max)
        => string.IsNullOrEmpty(value) ? value : value.Length <= max ? value : value[..max];
}
