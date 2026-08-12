using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using WebApi.Services;

namespace WebApi.Controllers;

/// <summary>
/// ProjectGuid handshake. Issues a short-lived session token + AES key.
/// RequestService (Protocol=Hermes) calls this BEFORE any data request.
/// </summary>
[ApiController]
[Route("api/auth")]
[AllowAnonymous]
public class AuthController : ControllerBase
{
    private readonly IProjectCatalog _projects;
    private readonly ISessionStore _sessions;
    private readonly HandshakeGuard _guard;
    private readonly CryptoJsService _crypto;
    private readonly HermesProjectsOptions _options;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        IProjectCatalog projects,
        ISessionStore sessions,
        HandshakeGuard guard,
        CryptoJsService crypto,
        IOptions<HermesProjectsOptions> options,
        ILogger<AuthController> logger)
    {
        _projects = projects;
        _sessions = sessions;
        _guard = guard;
        _crypto = crypto;
        _options = options.Value;
        _logger = logger;
    }

    public sealed class HandshakeEnvelope
    {
        public string? Data { get; set; }
    }

    [HttpPost("handshake")]
    public IActionResult Handshake([FromBody] HandshakeEnvelope? body)
    {
        var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        if (!_guard.TryConsumeRate("hs:" + ip))
            return StatusCode(429, new { code = 429, message = "Too many handshake attempts" });

        if (string.IsNullOrWhiteSpace(body?.Data))
            return BadRequest(new { code = 400, message = "Encrypted handshake payload required" });

        if (!TryReadProjectGuid(out var projectGuid))
            return BadRequest(new { code = 400, message = "X-Project-Guid header required" });

        var project = _projects.Find(projectGuid);
        if (project is null || !project.IsActive || string.IsNullOrWhiteSpace(project.SharedKey))
        {
            _logger.LogWarning("Handshake rejected: unknown or inactive project {Guid} from {IP}", projectGuid, ip);
            return Unauthorized(new { code = 401, message = "Unknown project" });
        }

        string plain;
        try
        {
            plain = _crypto.Decrypt(project.SharedKey, body.Data);
        }
        catch
        {
            return Unauthorized(new { code = 401, message = "Decrypt failed" });
        }

        using var doc = JsonDocument.Parse(plain);
        var root = doc.RootElement;
        var guidInBody = root.TryGetProperty("projectGuid", out var gEl) ? gEl.GetString() : null;
        var nonce = root.TryGetProperty("nonce", out var nEl) ? nEl.GetString() : null;
        var timestamp = root.TryGetProperty("timestamp", out var tEl) ? tEl.GetInt64() : 0;
        var clientId = root.TryGetProperty("clientId", out var cEl) ? cEl.GetString() : null;

        if (!Guid.TryParse(guidInBody, out var bodyGuid) || bodyGuid != projectGuid)
            return Unauthorized(new { code = 401, message = "ProjectGuid mismatch" });

        if (!_guard.IsTimestampFresh(timestamp, _options.HandshakeWindowSeconds))
            return Unauthorized(new { code = 401, message = "Stale handshake" });

        if (!_guard.TryAcceptNonce(nonce ?? ""))
            return Unauthorized(new { code = 401, message = "Replay rejected" });

        var lifetime = TimeSpan.FromMinutes(Math.Clamp(_options.SessionMinutes, 5, 60));
        var (token, encKey, expires) = _sessions.Issue(project, clientId, lifetime);

        var inner = JsonSerializer.Serialize(new
        {
            RequestId = token,
            EncryptionKey = encKey,
            ExpiresAt = expires,
            Schema = project.Schema,
            Project = project.Name
        });

        return Ok(new
        {
            code = 200,
            data = _crypto.Encrypt(project.SharedKey, inner)
        });
    }

    private bool TryReadProjectGuid(out Guid guid)
    {
        guid = Guid.Empty;
        if (!Request.Headers.TryGetValue("X-Project-Guid", out var raw))
            return false;
        return Guid.TryParse(raw.ToString(), out guid);
    }
}
