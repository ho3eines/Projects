namespace Tarazin.Services;

/// <summary>
/// Optional MAUI-only hook: fetches the encrypted SQL connection string from
/// the Web host once, before the first login. The web host does not register
/// it; both hosts otherwise run the identical in-process login
/// (AuthService → PBKDF2 → DbService). Wrong credentials must return
/// <c>false</c> (so the shared login UI show the same message as the web);
/// transport/server failures may throw <see cref="SafeAuthenticationException"/>.
/// </summary>
public interface IConnectionBootstrapper
{
    /// <summary>True once a usable connection string is available in memory.</summary>
    bool IsReady { get; }

    /// <summary>Verifies the credentials with the Web host and stores the
    /// decrypted connection string in memory. Returns false only for invalid
    /// credentials.</summary>
    Task<bool> BootstrapAsync(string username, string password, CancellationToken ct = default);
}

/// <summary>Optional hook used by MAUI to erase its in-memory connection string on logout.</summary>
public interface ICredentialSessionRevoker
{
    Task RevokeAndClearAsync(CancellationToken ct = default);
}

public sealed class SafeAuthenticationException : Exception
{
    public SafeAuthenticationException(string code, string safeMessage) : base(safeMessage)
    {
        Code = code;
    }

    public string Code { get; }
}
