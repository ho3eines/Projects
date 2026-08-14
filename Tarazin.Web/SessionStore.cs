using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using Tarazin.Services;

namespace Tarazin.Web;

/// <summary>
/// Web-host implementation of <see cref="ISessionStore"/>: persists
/// <see cref="UserSessionData"/> in the browser's protected session storage.
/// ProtectedBrowserStorage encrypts the payload and lives in the ASP.NET Core
/// shared framework (no extra package), so the signed-in session survives a
/// page refresh without storing the password (only identity/RBAC keys).
/// </summary>
public sealed class ProtectedSessionStore : ISessionStore
{
    private const string Key = "tarazin.session";
    private readonly ProtectedSessionStorage _storage;

    public ProtectedSessionStore(ProtectedSessionStorage storage)
    {
        _storage = storage;
    }

    public async ValueTask<UserSessionData?> LoadAsync(CancellationToken ct = default)
    {
        var result = await _storage.GetAsync<UserSessionData>(Key);
        return result.Success ? result.Value : null;
    }

    public async ValueTask SaveAsync(UserSessionData data, CancellationToken ct = default)
    {
        await _storage.SetAsync(Key, data);
    }

    public async ValueTask ClearAsync(CancellationToken ct = default)
    {
        await _storage.DeleteAsync(Key);
    }
}
