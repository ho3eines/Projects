using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Services;

namespace WebApi.Controllers;

/// <summary>
/// Encrypted named-TSQL endpoint used by RequestService after handshake.
/// SqlStr MUST be a script name. Raw SQL is rejected.
/// Schema is taken from the session (ProjectGuid), never from the client.
/// </summary>
[ApiController]
[Route("api/Data")]
[AllowAnonymous]
public class DataController : ControllerBase
{
    private readonly ISessionStore _sessions;
    private readonly ISystemQueryExecutor _executor;
    private readonly CryptoJsService _crypto;
    private readonly ILogger<DataController> _logger;

    public DataController(
        ISessionStore sessions,
        ISystemQueryExecutor executor,
        CryptoJsService crypto,
        ILogger<DataController> logger)
    {
        _sessions = sessions;
        _executor = executor;
        _crypto = crypto;
        _logger = logger;
    }

    [HttpPost]
    public async Task<IActionResult> Post([FromBody] string? encdata)
    {
        var session = ReadSession();
        if (session is null)
            return Unauthorized(new { code = 401, message = "Handshake required" });

        if (string.IsNullOrWhiteSpace(encdata))
            return BadRequest(new { code = 400, message = "Empty payload" });

        string plain;
        try
        {
            plain = _crypto.Decrypt(session.EncryptionKey, encdata);
        }
        catch
        {
            return Unauthorized(new { code = 401, message = "Payload decrypt failed — handshake again" });
        }

        using var doc = JsonDocument.Parse(plain);
        var root = doc.RootElement;
        var scriptName = root.TryGetProperty("SqlStr", out var sqlEl) ? sqlEl.GetString() : null;
        var isExec = root.TryGetProperty("IsExec", out var exEl) && exEl.GetBoolean();
        var isScalar = root.TryGetProperty("IsScalar", out var scEl) && scEl.GetBoolean();
        object? parameters = root.TryGetProperty("Parameters", out var pEl) && pEl.ValueKind is JsonValueKind.Object
            ? pEl.Clone()
            : null;

        if (!NamedScriptRules.IsSafeScriptName(scriptName))
        {
            _logger.LogWarning("Rejected non-named script from {Project}: {Script}", session.ProjectName, scriptName);
            return BadRequest(new { code = 400, message = "Only named TSQL scripts are allowed" });
        }

        // Force schema from ProjectGuid session — client cannot hop projects.
        var schema = session.Schema;

        try
        {
            if (isScalar)
            {
                var value = await _executor.ScalarAsync(scriptName!, parameters, schema);
                var json = JsonSerializer.Serialize(value);
                return Ok(new { code = 200, data = _crypto.Encrypt(session.EncryptionKey, json) });
            }

            if (isExec)
            {
                var affected = await _executor.ExecuteAsync(scriptName!, parameters, schema);
                var json = JsonSerializer.Serialize(new { AffectedRows = affected });
                return Ok(new { code = 200, data = _crypto.Encrypt(session.EncryptionKey, json) });
            }

            var rows = await _executor.QueryAsync(scriptName!, parameters, schema);
            var list = rows.Select(r =>
            {
                if (r is IDictionary<string, object> map)
                    return map.ToDictionary(kv => kv.Key, kv => kv.Value);
                return r;
            }).ToList();
            var listJson = JsonSerializer.Serialize(list);
            return Ok(new { code = 200, data = _crypto.Encrypt(session.EncryptionKey, listJson) });
        }
        catch (FileNotFoundException)
        {
            return NotFound(new { code = 404, message = $"Script not found: {schema}/{scriptName}" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Script {Schema}/{Script} failed", schema, scriptName);
            return StatusCode(500, new { code = 500, message = ex.Message });
        }
    }

    private HermesSession? ReadSession()
    {
        if (!Request.Headers.TryGetValue("X-API-Key", out var raw))
            return null;
        return _sessions.Validate(raw.ToString());
    }
}
