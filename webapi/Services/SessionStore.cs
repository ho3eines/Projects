using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;

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
    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
}

public interface ISessionStore
{
    (string token, string encryptionKey, DateTimeOffset expiresAt) Issue(HermesProject project, string? clientId, TimeSpan lifetime);
    HermesSession? Validate(string token);
    void Revoke(string token);
}

public sealed class SessionStore : ISessionStore
{
    private readonly ConcurrentDictionary<string, HermesSession> _sessions = new();

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
        _sessions[session.TokenHash] = session;
        return (token, encryptionKey, expires);
    }

    public HermesSession? Validate(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
            return null;
        if (!_sessions.TryGetValue(Hash(token), out var session))
            return null;
        if (session.ExpiresAt <= DateTimeOffset.UtcNow)
        {
            _sessions.TryRemove(session.TokenHash, out _);
            return null;
        }
        return session;
    }

    public void Revoke(string token) => _sessions.TryRemove(Hash(token), out _);

    private static string Hash(string token)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
