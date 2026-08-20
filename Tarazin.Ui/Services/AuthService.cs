using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// One identical login flow for both hosts. Web verifies directly on the
/// server; MAUI runs the very same local PBKDF2 check — the only difference is
/// that on a cold start the MAUI provider first fetches the encrypted
/// connection string from the Web host (<see cref="IConnectionBootstrapper"/>),
/// and that API verifies the same credentials before delivering it.
/// </summary>
public sealed class AuthService
{
    private readonly DbService _db;
    private readonly IConnectionBootstrapper? _bootstrapper;

    public AuthService(DbService db, IEnumerable<IConnectionBootstrapper> bootstrappers)
    {
        _db = db;
        _bootstrapper = bootstrappers.SingleOrDefault();
    }

    /// <summary>Returns the signed-in user, or null on bad credentials.</summary>
    public async Task<UserRow?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            return null;

        // MAUI cold start: the connection string is not in memory yet. Fetch it
        // once from the Web host; the API verifies these credentials and
        // returns false for wrong ones — the UI then shows exactly the same
        // message as the local path below. Already-bootstrapped sessions skip
        // this entirely, so steady-state login never touches the network.
        if (_bootstrapper is not null && !_bootstrapper.IsReady &&
            !await _bootstrapper.BootstrapAsync(username.Trim(), password, ct))
        {
            return null;
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
