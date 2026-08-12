using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// Login/logout against <c>[central].[Users]</c>. Runs in the Blazor Server
/// process; passwords are verified with PBKDF2 (never stored/transmitted as
/// plaintext, never shipped to a WASM client).
/// </summary>
public sealed class AuthService
{
    private readonly DbService _db;

    public AuthService(DbService db)
    {
        _db = db;
    }

    /// <summary>Returns the signed-in user, or null on bad credentials.</summary>
    public async Task<UserRow?> AuthenticateAsync(string username, string password, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            return null;

        var user = await _db.QueryFirstOrDefaultAsync<UserRow>(
            "central", "UserAuthenticate", new { Username = username.Trim() }, ct);

        if (user is null || !user.IsActive || !PasswordHasher.Verify(password, user.PasswordHash))
            return null;

        return user;
    }
}
