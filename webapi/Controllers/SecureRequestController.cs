using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.Data.SqlClient;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Controllers;

/// <summary>
/// THE single secure endpoint for ALL client projects:
/// POST /api/request/{query|execute|scalar|script}
///
/// Security layers:
///  1. X-API-Key          → identify which project/app
///  2. X-Timestamp        → anti-replay (30s window)
///  3. X-Signature        → HMAC-SHA256 over "timestamp|body" (anti-tamper)
///  4. X-Project-Guid     → required, identifies schema/project
///  5. X-User-Id          → optional; if RequireUser=true and missing → 403
///
/// Auto-provisioning:
///  - If payload.Model is present, the server inspects the table via
///    INFORMATION_SCHEMA and CREATES the table or ALTERs missing columns
///    (with SqlType provided by the client's model attributes).
///
/// Observability:
///  - Every request is written to RequestEvents table (duration, CPU, RAM,
///    status, error, project, user) for later analysis & optimization.
/// </summary>
[ApiController]
[Route("api/request/{method}")]
public class SecureRequestController : ControllerBase
{
    private readonly RequestServiceConfig _cfg;
    private readonly RequestEventLogger _eventLog;
    private readonly ILogger<SecureRequestController> _log;
    private readonly SessionStore _sessions;

    public SecureRequestController(
        IOptions<RequestServiceConfig> cfg,
        RequestEventLogger eventLog,
        ILogger<SecureRequestController> log,
        SessionStore sessions)
    {
        _cfg = cfg.Value;
        _eventLog = eventLog;
        _log = log;
        _sessions = sessions;
    }

    [HttpPost]
    public async Task<IActionResult> Execute(
        [FromRoute] string method,
        [FromBody] DeployRequestPayloadDto payload,
        CancellationToken ct)
    {
        var sw = Stopwatch.StartNew();
        var correlationId = payload?.CorrelationId ?? Guid.NewGuid();

        // ---------- 1) Read raw body for signature validation ----------
        string rawBody;
        try
        {
            Request.EnableBuffering();
            Request.Body.Position = 0;
            using var reader = new StreamReader(Request.Body, Encoding.UTF8, leaveOpen: true);
            rawBody = await reader.ReadToEndAsync(ct);
            Request.Body.Position = 0;
        }
        catch (Exception ex)
        {
            return await RejectAsync(400, "BODY_READ_FAIL", ex.Message, sw, correlationId, null);
        }

        // ---------- 2) Validate security headers ----------
        var (ok, sec, secError) = TryResolveSecurity(rawBody);
        if (!ok)
            return await RejectAsync(401, secError, secError, sw, correlationId, null);
        if (payload is null)
        {
            return await RejectAsync(400, "EMPTY_PAYLOAD", "Payload is empty", sw, correlationId, sec);
        }

        // ---------- 3) Decrypt if encrypted ----------
        if (Request.Headers.ContainsKey("X-Encrypted"))
        {
            var decrypted = TryDecrypt(payload.EncryptedPayload);
            if (decrypted is null)
                return await RejectAsync(400, "DECRYPT_FAIL", "Unable to decrypt payload", sw, correlationId, sec);
            try { payload = JsonSerializer.Deserialize<DeployRequestPayloadDto>(decrypted, JsonOpts)!; }
            catch { return await RejectAsync(400, "DECRYPT_FAIL", "Decrypted payload is not valid JSON", sw, correlationId, sec); }
        }

        // ---------- 3.5) Session validation ----------
        // X-Auth-Token باید معتبر باشد — SessionStore آن را Touch می‌کند
        var authToken = Request.Headers["X-Auth-Token"].FirstOrDefault();
        if (!string.IsNullOrEmpty(authToken) && _sessions.Validate(authToken, out var activeSession))
        {
            // Session فعال — projectGuid از session اصل است
            sec = new SecurityContext(sec!.ApiKey, activeSession!.ProjectGuid, sec.UserId);
        }
        else
        {
            return await RejectAsync(401, "SESSION_EXPIRED",
                "Session token is missing or expired — please login again", sw, correlationId, sec);
        }

        // ---------- 4) UserId enforcement ----------
        if (payload.RequireUser && (!payload.UserId.HasValue || payload.UserId == Guid.Empty))
        {
            return await RejectAsync(403, "USER_REQUIRED", "This operation requires a valid UserId", sw, correlationId, sec);
        }
        // اگر RequireUser نباشد ولی UserId داده شده باشد → در لاگ ثبت می‌شود (نشانه مسئولیت)

        // ---------- 5) TSQl is mandatory ----------
        if (string.IsNullOrWhiteSpace(payload.Tsql) && string.IsNullOrWhiteSpace(payload.ScriptName))
        {
            return await RejectAsync(400, "SQL_REQUIRED", "Either Tsql or ScriptName is required", sw, correlationId, sec);
        }

        // ---------- 6) Auto-provision table/columns if Model present ----------
        if (payload.Model is not null)
        {
            await ProvisionSchemaAsync(payload.Model, correlationId, sec, activeSession!);
        }

        // ---------- 7) Execute ----------
        try
        {
            object? result;
            switch (method.ToLowerInvariant())
            {
                case "query":
                    result = await ExecuteQueryAsync(payload, activeSession!);
                    break;
                case "execute":
                    result = await ExecuteCommandAsync(payload, activeSession!);
                    break;
                case "scalar":
                    result = await ExecuteScalarAsync(payload, activeSession!);
                    break;
                case "script":
                    result = await ExecuteScriptAsync(payload, activeSession!);
                    break;
                default:
                    return await RejectAsync(400, "BAD_METHOD", $"Unknown method: {method}", sw, correlationId, sec);
            }

            sw.Stop();
            var (cpuMs, ramMb) = ReadMetrics();
            await _eventLog.LogAsync(BuildEvent(sec, payload, sw, 200, null, null, correlationId, ReadMetrics()));
            return Ok(new DeployResponseDto
            {
                CorrelationId = correlationId,
                TotalCount = (result as dynamic)?.Count ?? 0,
                Data = result,
                AffectedRows = (result as int?) ?? 0,
                DurationMs = sw.ElapsedMilliseconds
            });
        }
        catch (SqlException sqlEx)
        {
            sw.Stop();
            _log.LogError(sqlEx, "SQL error for {Method}", method);
            var (cpuMs, ramMb) = ReadMetrics();
            await _eventLog.LogAsync(BuildEvent(sec, payload, sw, 500, "SQL_ERROR", sqlEx.Message, correlationId, ReadMetrics()));
            return StatusCode(500, new DeployResponseDto
            {
                CorrelationId = correlationId,
                Error = $"SQL_ERROR: {sqlEx.Message}",
                DurationMs = sw.ElapsedMilliseconds
            });
        }
        catch (Exception ex)
        {
            sw.Stop();
            _log.LogError(ex, "Unexpected error for {Method}", method);
            await _eventLog.LogAsync(BuildEvent(sec, payload, sw, 500, "INTERNAL_ERROR", ex.Message, correlationId, ReadMetrics()));
            return StatusCode(500, new DeployResponseDto
            {
                CorrelationId = correlationId,
                Error = $"INTERNAL_ERROR: {ex.Message}",
                DurationMs = sw.ElapsedMilliseconds
            });
        }
    }

    // ===================== EXECUTION =====================

    /// <summary>اتصال به دیتابیس اختصاصی پروژه — از جدول Projects خوانده می‌شود</summary>
    private async Task<SqlConnection> OpenProjectConnectionAsync(ServerSession session)
    {
        // خواندن ConnectionString پروژه از جدول Projects
        await using var admin = new SqlConnection(_cfg.ConnectionString);
        await admin.OpenAsync();
        var connStr = await admin.ExecuteScalarAsync<string>(
            "SELECT ConnectionString FROM [dbo].[Projects] WHERE ProjectGuid = @guid",
            new { guid = session.ProjectGuid });

        if (string.IsNullOrEmpty(connStr))
            throw new InvalidOperationException($"No connection string configured for project {session.ProjectGuid}");

        var conn = new SqlConnection(connStr);
        await conn.OpenAsync();
        return conn;
    }

    private async Task<object> ExecuteQueryAsync(DeployRequestPayloadDto payload, ServerSession session)
    {
        var sql = await ResolveNamedScriptSqlAsync(payload, session);
        await using var conn = await OpenProjectConnectionAsync(session);
        var rows = await conn.QueryAsync(sql, BuildParams(payload.Parameters));
        return rows.ToList();
    }

    private async Task<object> ExecuteCommandAsync(DeployRequestPayloadDto payload, ServerSession session)
    {
        var sql = await ResolveNamedScriptSqlAsync(payload, session);
        await using var conn = await OpenProjectConnectionAsync(session);
        return await conn.ExecuteAsync(sql, BuildParams(payload.Parameters));
    }

    private async Task<object> ExecuteScalarAsync(DeployRequestPayloadDto payload, ServerSession session)
    {
        var sql = await ResolveNamedScriptSqlAsync(payload, session);
        await using var conn = await OpenProjectConnectionAsync(session);
        return await conn.ExecuteScalarAsync(sql, BuildParams(payload.Parameters));
    }

    private async Task<object> ExecuteScriptAsync(DeployRequestPayloadDto payload, ServerSession session)
    {
        var sql = await ResolveNamedScriptSqlAsync(payload, session);
        await using var conn = await OpenProjectConnectionAsync(session);
        var rows = await conn.QueryAsync(sql, BuildParams(payload.Parameters));
        return rows.ToList();
    }

    /// <summary>
    /// Resolves a client request to the SQL of a *named* script under the
    /// session's own schema folder. Raw SQL is never executed: query/execute/scalar
    /// and script all funnel through this single, validated, schema-scoped loader
    /// (SECURITY.md layer 4 — "named scripts only"; ADR-001 schema lock).
    /// </summary>
    private async Task<string> ResolveNamedScriptSqlAsync(DeployRequestPayloadDto payload, ServerSession session)
    {
        // ScriptName may be empty when the client sends it as Tsql (legacy RunScriptAsync).
        var scriptName = (payload.ScriptName ?? payload.Tsql ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(scriptName) || !NamedScriptRules.IsSafeScriptName(scriptName))
            throw new InvalidOperationException("Only named TSQL scripts are allowed");

        var rel = scriptName.Replace(".sql", "", StringComparison.OrdinalIgnoreCase).Replace('\\', '/');
        var safeName = Path.GetFileName(rel);
        var schema = string.IsNullOrWhiteSpace(session.Schema) ? "dbo" : SanitizeIdentifier(session.Schema);

        // Prefer the session's own schema folder; fall back to root/admin/shared only
        // for scripts that legitimately live outside a product schema.
        var candidates = new[]
        {
            // per-schema layout: Data/Scripts/{schema}/{name}.sql (7-product platform)
            Path.Combine(_cfg.ScriptsRoot!, schema, $"{safeName}.sql"),
            Path.Combine(_cfg.ScriptsRoot!, $"{safeName}.sql"),
            Path.Combine(_cfg.ScriptsRoot!, "admin", $"{safeName}.sql"),
            Path.Combine(_cfg.ScriptsRoot!, "shared", $"{safeName}.sql")
        };
        var path = candidates.FirstOrDefault(System.IO.File.Exists);
        if (path is null) throw new FileNotFoundException($"Script not found: {safeName}");

        return await System.IO.File.ReadAllTextAsync(path);
    }

    // ===================== SCHEMA GUARD =====================

    private async Task ProvisionSchemaAsync(ModelSchemaInfoDto model, Guid correlationId, SecurityContext? sec, ServerSession session)
    {
        if (model.Columns.Count == 0) return;

        // SECURITY: client-driven DDL (table/column auto-provisioning driven by a
        // WASM-extractable Model + SqlType/DefaultExpression) is DISABLED. It let a
        // caller inject arbitrary T-SQL through unescaped SqlType/DefaultExpression
        // and contradicts ADR-001's schema-lock (schemas are owned by _Ensure.sql,
        // never shaped by the client). Keep the hook so callers get a clear signal.
        _log.LogWarning("Auto-provisioning is disabled (requested {Schema}.{Table} by {Project}) — schemas are defined by named _Ensure.sql scripts only",
            SanitizeIdentifier(model.Schema), SanitizeIdentifier(model.Table), sec?.ApiKey ?? "?");
    }

    private static string SanitizeIdentifier(string input)
    {
        var cleaned = new string(input.Where(ch => char.IsLetterOrDigit(ch) || ch == '_').ToArray());
        return string.IsNullOrEmpty(cleaned) ? "dbo" : cleaned;
    }

    // ===================== SECURITY =====================

    private (bool ok, SecurityContext? sec, string error) TryResolveSecurity(string body)
   {
        SecurityContext? sec = null; string error = null!;

        if (!Request.Headers.TryGetValue("X-API-Key", out var apiKey) || string.IsNullOrEmpty(apiKey))
            return Fail("Missing X-API-Key header");
        if (!_cfg.ValidateApiKey(apiKey!))
            return Fail("Invalid API key");

        if (!Request.Headers.TryGetValue("X-Timestamp", out var tsStr) || !long.TryParse(tsStr, out var ts))
            return Fail("Missing or invalid X-Timestamp");
        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        if (Math.Abs(now - ts) > _cfg.TimestampToleranceSeconds)
            return Fail("Request timestamp expired (replay protection)");

        if (!Request.Headers.TryGetValue("X-Signature", out var sig) || string.IsNullOrEmpty(sig))
            return Fail("Missing X-Signature header");

        if (!Request.Headers.TryGetValue("X-Project-Guid", out var guidStr) || !Guid.TryParse(guidStr, out var projectGuid))
            return Fail("Missing or invalid X-Project-Guid");

        Guid? userId = null;
        if (Request.Headers.TryGetValue("X-User-Id", out var userStr) && Guid.TryParse(userStr, out var ug))
            userId = ug;

        // Validate HMAC over "timestamp|body"
        var expected = HmacSha256(_cfg.Secret, $"{ts}|{body}");
        var provided = sig!.ToString().ToLowerInvariant();
        if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(expected), Encoding.UTF8.GetBytes(provided)))
            return Fail("HMAC signature mismatch");

        sec = new SecurityContext(apiKey!, projectGuid, userId);
        return (true, sec, string.Empty);

        (bool ok, SecurityContext? sec, string error) Fail(string msg) => (false, null, msg);
    }

    private string? TryDecrypt(string? encrypted)
    {
        try { return System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(encrypted ?? string.Empty)); }
        catch { return null; }
    }

    private static string HmacSha256(string secret, string data)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(data))).ToLowerInvariant();
    }

    // ===================== HELPERS =====================

    private static DynamicParameters BuildParams(Dictionary<string, object?>? p)
    {
        var dp = new DynamicParameters();
        if (p is not null)
            foreach (var kv in p) dp.Add(kv.Key, kv.Value ?? DBNull.Value);
        return dp;
    }

    private static (long cpuMs, double ramMb) ReadMetrics()
    {
        try
        {
            var proc = Process.GetCurrentProcess();
            return ((long)proc.TotalProcessorTime.TotalMilliseconds, Math.Round(proc.WorkingSet64 / (1024.0 * 1024.0), 2));
        }
        catch { return (0, 0); }
    }

    private RequestEvent BuildEvent(
        SecurityContext? sec, DeployRequestPayloadDto payload, Stopwatch sw,
        int status, string? errorCode, string? errorMessage, Guid correlationId, (long, double) metrics)
    {
        return new RequestEvent
        {
            CorrelationId = correlationId,
            ApiKey = sec?.ApiKey ?? "?",
            ProjectGuid = sec?.ProjectGuid ?? Guid.Empty,
            UserId = sec?.UserId,
            Endpoint = $"{Request.Method} {Request.Path}",
            StatusCode = status,
            DurationMs = sw.ElapsedMilliseconds,
            CpuTimeMs = metrics.Item1,
            RamUsedMb = metrics.Item2,
            TimestampUtc = DateTime.UtcNow,
            ErrorMessage = errorCode ?? errorMessage
        };
    }

    private async Task<IActionResult> RejectAsync(
        int status, string errorCode, string message, Stopwatch sw, Guid correlationId, SecurityContext? sec)
    {
        sw.Stop();
        var (cpuMs, ramMb) = ReadMetrics();
        await _eventLog.LogAsync(new RequestEvent
        {
            CorrelationId = correlationId,
            ApiKey = sec?.ApiKey ?? "?",
            ProjectGuid = sec?.ProjectGuid ?? Guid.Empty,
            UserId = sec?.UserId,
            Endpoint = $"{Request.Method} {Request.Path}",
            StatusCode = status,
            DurationMs = sw.ElapsedMilliseconds,
            CpuTimeMs = cpuMs,
            RamUsedMb = ramMb,
            TimestampUtc = DateTime.UtcNow,
            ErrorMessage = errorCode
        });
        return StatusCode(status, new DeployResponseDto
        {
            CorrelationId = correlationId,
            Error = $"{errorCode}: {message}",
            DurationMs = sw.ElapsedMilliseconds
        });
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };
}

/// <summary>زمینه احراز هویت امنیتی یک درخواست</summary>
public sealed record SecurityContext(string ApiKey, Guid ProjectGuid, Guid? UserId);

/// <summary>تنظیمات سرویس درخواست — از بخش RequestService در appsettings</summary>
public sealed class RequestServiceConfig
{
    public string? ConnectionString { get; set; }
    public List<string> ApiKeys { get; set; } = new();
    public string Secret { get; set; } = string.Empty;
    public int TimestampToleranceSeconds { get; set; } = 30;
    public string? ScriptsRoot { get; set; }

    public bool ValidateApiKey(string key) => ApiKeys.Contains(key, StringComparer.Ordinal);
}