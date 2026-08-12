using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public sealed class HermesSession
{
    public required string TokenHash { get; init; }
    public required Guid ProjectGuid { get; init; }
    public required string Schema { get; init; }
    public required string ProjectName { get; init; }
    public required string EncryptionKey { get; init; }
    public required DateTimeOffset ExpiresAt { get; init; }
    public string? ClientId { get; init; }
    public int? UserId { get; set; }
    public string? Username { get; set; }
    public string? Role { get; set; }
    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
}

public interface ISessionStore
{
    (string token, string encryptionKey, DateTimeOffset expiresAt) Issue(HermesProject project, string? clientId, TimeSpan lifetime);
    HermesSession? Validate(string token);
    void AttachUser(string token, HermesUser user);
    void Revoke(string token);
}

public sealed class SessionStore : ISessionStore
{
    private readonly ConcurrentDictionary<string, HermesSession> _memory = new();
    private readonly string? _cs;
    private readonly CryptoJsService _crypto;
    private readonly string _protectKey;
    private readonly ILogger<SessionStore> _log;

    public SessionStore(
        IOptions<ConnectionStringsOptions> cs,
        IOptions<AuthOptions> auth,
        CryptoJsService crypto,
        ILogger<SessionStore> log)
    {
        _cs = cs.Value.DefaultConnection;
        _crypto = crypto;
        if (string.IsNullOrWhiteSpace(auth.Value.Key))
            throw new InvalidOperationException(
                "Auth:Key is not configured. A hard-coded fallback key would be a public secret — refuse to start.");
        _protectKey = auth.Value.Key;
        _log = log;
    }

    public (string token, string encryptionKey, DateTimeOffset expiresAt) Issue(HermesProject project, string? clientId, TimeSpan lifetime)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var encryptionKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        var expires = DateTimeOffset.UtcNow.Add(lifetime);
        var session = new HermesSession
        {
            TokenHash = Hash(token),
            ProjectGuid = project.Guid,
            Schema = project.Schema,
            ProjectName = project.Name,
            EncryptionKey = encryptionKey,
            ExpiresAt = expires,
            ClientId = clientId
        };
        _memory[session.TokenHash] = session;
        TrySql(() =>
        {
            using var conn = new SqlConnection(_cs);
            conn.Execute(@"
INSERT INTO [central].[Sessions]
    (TokenHash, ProjectGuid, SchemaName, ProjectName, EncryptionKeyProtected, UserId, ClientId, ExpiresAt, CreatedAt)
VALUES
    (@TokenHash, @ProjectGuid, @SchemaName, @ProjectName, @EncryptionKeyProtected, NULL, @ClientId, @ExpiresAt, SYSUTCDATETIME());",
                new
                {
                    session.TokenHash,
                    ProjectGuid = project.Guid,
                    SchemaName = project.Schema,
                    ProjectName = project.Name,
                    EncryptionKeyProtected = _crypto.Encrypt(_protectKey, encryptionKey),
                    ClientId = clientId,
                    ExpiresAt = expires.UtcDateTime
                });
        });
        return (token, encryptionKey, expires);
    }

    public HermesSession? Validate(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
            return null;
        var hash = Hash(token);
        if (_memory.TryGetValue(hash, out var cached))
        {
            if (cached.ExpiresAt > DateTimeOffset.UtcNow)
                return cached;
            _memory.TryRemove(hash, out _);
        }

        HermesSession? fromDb = null;
        TrySql(() =>
        {
            using var conn = new SqlConnection(_cs);
            var row = conn.QueryFirstOrDefault<SessionRow>(@"
SELECT TokenHash, ProjectGuid, SchemaName, ProjectName, EncryptionKeyProtected, UserId, ClientId, ExpiresAt
FROM [central].[Sessions] WHERE TokenHash = @hash AND ExpiresAt > SYSUTCDATETIME();",
                new { hash });
            if (row is null)
                return;
            fromDb = new HermesSession
            {
                TokenHash = row.TokenHash,
                ProjectGuid = row.ProjectGuid,
                Schema = row.SchemaName,
                ProjectName = row.ProjectName,
                EncryptionKey = _crypto.Decrypt(_protectKey, row.EncryptionKeyProtected),
                ExpiresAt = new DateTimeOffset(DateTime.SpecifyKind(row.ExpiresAt, DateTimeKind.Utc)),
                ClientId = row.ClientId,
                UserId = row.UserId
            };
            _memory[hash] = fromDb;
        });
        return fromDb;
    }

    public void AttachUser(string token, HermesUser user)
    {
        var session = Validate(token);
        if (session is null)
            return;
        session.UserId = user.UserId;
        session.Username = user.Username;
        session.Role = user.Role;
        TrySql(() =>
        {
            using var conn = new SqlConnection(_cs);
            conn.Execute("UPDATE [central].[Sessions] SET UserId = @UserId WHERE TokenHash = @TokenHash;",
                new { user.UserId, session.TokenHash });
        });
    }

    public void Revoke(string token)
    {
        var hash = Hash(token);
        _memory.TryRemove(hash, out _);
        TrySql(() =>
        {
            using var conn = new SqlConnection(_cs);
            conn.Execute("DELETE FROM [central].[Sessions] WHERE TokenHash = @hash;", new { hash });
        });
    }

    private void TrySql(Action action)
    {
        if (string.IsNullOrWhiteSpace(_cs))
            return;
        try { action(); }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Session SQL store unavailable — using memory only");
        }
    }

    private static string Hash(string token)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private sealed class SessionRow
    {
        public string TokenHash { get; set; } = "";
        public Guid ProjectGuid { get; set; }
        public string SchemaName { get; set; } = "";
        public string ProjectName { get; set; } = "";
        public string EncryptionKeyProtected { get; set; } = "";
        public int? UserId { get; set; }
        public string? ClientId { get; set; }
        public DateTime ExpiresAt { get; set; }
    }
}
