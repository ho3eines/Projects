using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// Preserves the existing login service while selecting the host-appropriate
/// preparation path: Web verifies directly on the server; MAUI first calls the
/// HTTPS credential broker and only then enables direct named-script SQL calls.
/// </summary>
public sealed class AuthService
{
    private readonly DbService _db;
    private readonly IRemoteAuthenticationService? _remote;

    public AuthService(DbService db, IEnumerable<IRemoteAuthenticationService> remoteServices)
    {
        _db = db;
        _remote = remoteServices.SingleOrDefault();
    }

    /// <summary>Returns the signed-in user, or null on bad credentials.</summary>
    public async Task<UserRow?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            return null;

        if (_remote is not null)
        {
            // MAUI: verify via the Web host (POST /api/mobile/login).
            return await _remote.AuthenticateAsync(username.Trim(), password, ct);
        }

        var user = await _db.QueryFirstOrDefaultAsync<UserRow>(
            "central", "UserAuthenticate", new { Username = username.Trim() }, ct);

        if (user is null || !user.IsActive || !PasswordHasher.Verify(password, user.PasswordHash))
            return null;

        // Do not keep the password hash in the UI model after verification.
        user.PasswordHash = "";
        return user;
    }
}
