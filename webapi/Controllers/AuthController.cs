using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using WebApi.Models;

namespace WebApi.Controllers;

/// <summary>
/// احراز هویت پروژه‌ها با webapi:
/// POST /api/auth/login
///   body: { projectGuid, loginToken (AES-encrypted), clientVersion }
/// جریان:
///   1) پروژه را در جدول Projects پیدا می‌کند (شامل ConnectionString و تنظیمات اختصاصی)
///   2) loginToken رمزنگاری‌شده را با EncryptionKey پروژه دیکریپت می‌کند
///   3) با LoginTokenHash مقایسه می‌کند (FixedTimeEquals)
///   4) در صورت موفقیت SessionToken می‌سازد و در SessionStore ثبت می‌کند
///   5) SessionTimeoutMinutes از جدول Projects خوانده می‌شود (قابل تنظیم در run-time)
/// </summary>
[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly RequestServiceConfig _cfg;
    private readonly SessionStore _sessions;
    private readonly ILogger<AuthController> _log;

    public AuthController(IOptions<RequestServiceConfig> cfg, SessionStore sessions, ILogger<AuthController> log)
    {
        _cfg = cfg.Value;
        _sessions = sessions;
        _log = log;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
    {
        if (request.ProjectGuid == Guid.Empty)
            return BadRequest(new { error = "ProjectGuid is required" });
        if (string.IsNullOrEmpty(request.LoginToken))
            return BadRequest(new { error = "LoginToken is required" });

        // 1) پیدا کردن پروژه از جدول Projects
        var project = await FindProjectAsync(request.ProjectGuid);
        if (project is null)
            return Unauthorized(new { error = "Project not found or inactive" });
        if (!project.IsActive)
            return Unauthorized(new { error = "Project is disabled" });

        // 2) دیکریپت loginToken با EncryptionKey پروژه
        string decrypted;
        try { decrypted = DecryptAes(request.LoginToken, project.EncryptionKey); }
        catch { return Unauthorized(new { error = "Invalid token encryption" }); }

        // 3) مقایسه امن با LoginTokenHash
        var hash = Sha256(decrypted);
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(hash), Encoding.UTF8.GetBytes(project.LoginTokenHash)))
        {
            _log.LogWarning("Failed login for project {Project}", request.ProjectGuid);
            return Unauthorized(new { error = "Invalid login token" });
        }

        // 4) ساخت نشست — Timeout از جدول پروژه (به دقیقه)
        var session = _sessions.Create(project);

        _log.LogInformation("Project {Name} logged in, session {Token} (timeout {Timeout} min)",
            project.Name, session.SessionToken[..8], project.SessionTimeoutMinutes);

        return Ok(new LoginResponseDto
        {
            SessionToken = session.SessionToken,
            ExpiresInSeconds = project.SessionTimeoutMinutes * 60,
            ExpiresInMinutes = project.SessionTimeoutMinutes,
            Project = new ProjectInfoDto
            {
                ProjectGuid = project.ProjectGuid,
                Name = project.Name,
                Schema = project.Schema,
                SessionTimeoutMinutes = project.SessionTimeoutMinutes,
                SessionTimeoutSeconds = checked(project.SessionTimeoutMinutes * 60),
                DatabaseName = project.DatabaseName
            }
        });
    }

    /// <summary>خروج از نشست — توکن باطل می‌شود</summary>
    [HttpPost("logout")]
    public IActionResult Logout([FromHeader(Name = "X-Auth-Token")] string? token)
    {
        if (!string.IsNullOrEmpty(token))
            _sessions.Revoke(token);
        return Ok(new { message = "Logged out" });
    }

    private async Task<ProjectDefinition?> FindProjectAsync(Guid projectGuid)
    {
        await using var conn = new SqlConnection(_cfg.ConnectionString);
        await conn.OpenAsync();
        return await conn.QueryFirstOrDefaultAsync<ProjectDefinition>(
            "SELECT * FROM [dbo].[Projects] WHERE ProjectGuid = @guid", new { guid = projectGuid });
    }

    /// <summary>
    /// Decrypts the client loginToken. The Blazor WASM client encrypts with
    /// AES-256-CBC (PKCS7): key = SHA256(UTF8(key)), random 16-byte IV prepended
    /// to the ciphertext, all Base64 (see blazordeployservice/wwwroot/js/interop.js).
    /// </summary>
    private static string DecryptAes(string base64, string key)
    {
        var full = Convert.FromBase64String(base64);
        if (full.Length <= 16)
            throw new InvalidOperationException("Invalid token payload");

        var iv = full[..16];
        var cipher = full[16..];

        using var aes = Aes.Create();
        aes.Key = SHA256.HashData(Encoding.UTF8.GetBytes(key));
        aes.IV = iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;
        using var dec = aes.CreateDecryptor();
        var plain = dec.TransformFinalBlock(cipher, 0, cipher.Length);
        return Encoding.UTF8.GetString(plain);
    }

    private static string Sha256(string input)
    {
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(input))).ToLowerInvariant();
    }
}

/// <summary>DTO درخواست ورود</summary>
public sealed class LoginRequestDto
{
    public Guid ProjectGuid { get; set; }
    public string LoginToken { get; set; } = default!;
    public string ClientVersion { get; set; } = "1.0.100";
}

/// <summary>DTO پاسخ ورود</summary>
public sealed class LoginResponseDto
{
    public string SessionToken { get; set; } = default!;
    public int ExpiresInSeconds { get; set; }
    public int ExpiresInMinutes { get; set; }
    public ProjectInfoDto Project { get; set; } = new();
}

/// <summary>DTO اطلاعات پروژه برای کلاینت</summary>
public sealed class ProjectInfoDto
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public int SessionTimeoutMinutes { get; set; } = 10;
    public int SessionTimeoutSeconds { get; set; } = 600;
    public string DatabaseName { get; set; } = string.Empty;
}

/// <summary>
/// نگهداری نشست‌های فعال در حافظه (ConcurrentDictionary)
/// - هر نشست Timeout اختصاصی دارد (از جدول پروژه)
/// - Touch با هر درخواست معتبر — سکوت بیش از Timeout → انقضا
/// - پاکسازی دوره‌ای نشست‌های منقضی
/// </summary>
public sealed class SessionStore
{
    private readonly ConcurrentDictionary<string, ServerSession> _sessions = new();
    private readonly ILogger<SessionStore> _log;

    public SessionStore(ILogger<SessionStore> log)
    {
        _log = log;
        // پاکسازی دوره‌ای نشست‌های منقضی (هر ۵ دقیقه)
        var _ = Task.Run(async () =>
        {
            while (true)
            {
                await Task.Delay(TimeSpan.FromMinutes(5));
                CleanupExpired();
            }
        });
    }

    public ServerSession Create(ProjectDefinition project)
    {
        var session = new ServerSession
        {
            SessionToken = GenerateToken(),
            ProjectGuid = project.ProjectGuid,
            CreatedAtUtc = DateTime.UtcNow,
            LastActivityUtc = DateTime.UtcNow,
            TimeoutMinutes = project.SessionTimeoutMinutes,
            DatabaseName = project.DatabaseName,
            Schema = project.Schema
        };
        _sessions[session.SessionToken] = session;
        return session;
    }

    /// <summary>اعتبارسنجی توکن + Touch — اگر منقضی باشد حذف و false</summary>
    public bool Validate(string token, out ServerSession? session)
    {
        session = null;
        if (_sessions.TryGetValue(token, out var s))
        {
            if (s.IsExpired)
            {
                _sessions.TryRemove(token, out _);
                _log.LogInformation("Session {Token} expired after {Min} min idle", token[..8], s.TimeoutMinutes);
                return false;
            }
            s.Touch();
            session = s;
            return true;
        }
        return false;
    }

    public void Revoke(string token) => _sessions.TryRemove(token, out _);

    public int ActiveCount => _sessions.Count;

    public IReadOnlyList<ServerSession> All => _sessions.Values.ToList();

    private void CleanupExpired()
    {
        foreach (var (token, s) in _sessions)
        {
            if (s.IsExpired) _sessions.TryRemove(token, out _);
        }
    }

    private static string GenerateToken()
    {
        // 32 bytes random → 64 hex chars — غیرقابل پیش‌بینی
        return Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
    }
}

/// <summary>نشست فعال در سرور</summary>
public sealed class ServerSession
{
    public string SessionToken { get; set; } = default!;
    public Guid ProjectGuid { get; set; }
    public string DatabaseName { get; set; } = string.Empty;
    public string Schema { get; set; } = "dbo";
    public DateTime CreatedAtUtc { get; set; }
    public DateTime LastActivityUtc { get; set; }
    public int TimeoutMinutes { get; set; } = 10;

    public bool IsExpired => (DateTime.UtcNow - LastActivityUtc).TotalMinutes > TimeoutMinutes;
    public void Touch() => LastActivityUtc = DateTime.UtcNow;
}