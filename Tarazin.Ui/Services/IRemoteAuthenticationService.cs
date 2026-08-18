using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>Optional MAUI authentication/bootstrap transport. The web host does not register it.</summary>
public interface IRemoteAuthenticationService
{
    Task<UserRow?> AuthenticateAsync(
        string username,
        string password,
        Guid customerGuid,
        CancellationToken ct = default);
}

/// <summary>Optional hook used by MAUI to revoke and erase its in-memory credential on logout.</summary>
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
