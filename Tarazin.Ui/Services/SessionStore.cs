namespace Tarazin.Services;

/// <summary>
/// Browser-side persistence of the signed-in session.
///
/// <see cref="UserSession"/> is scoped to the Blazor Server circuit, so a page
/// refresh (F5) tears down the circuit — and the in-memory session — which
/// currently logs the user out. This store lets the session survive a refresh
/// by round-tripping <see cref="UserSessionData"/> through browser storage.
///
/// The abstraction is host-specific on purpose:
///   - the web host registers a <c>ProtectedSessionStorage</c>-backed
///     implementation (encrypted, survives refresh);
///   - the MAUI hybrid host registers nothing — a single-user desktop app
///     keeps the current behaviour and never touches browser storage.
/// </summary>
public interface ISessionStore
{
    ValueTask<UserSessionData?> LoadAsync(CancellationToken ct = default);
    ValueTask SaveAsync(UserSessionData data, CancellationToken ct = default);
    ValueTask ClearAsync(CancellationToken ct = default);
}

/// <summary>
/// Serializable snapshot of the signed-in user. Contains identity/RBAC only —
/// never the password or its hash.
/// </summary>
public sealed class UserSessionData
{
    public int UserId { get; set; }
    public string UserName { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Role { get; set; } = "";
    public string RoleTitle { get; set; } = "";
    public int RoleId { get; set; }
    public List<string> Permissions { get; set; } = new();
    public int? ActiveCompanyId { get; set; }
    public string? ActiveCompanyName { get; set; }
    public int? ActiveFiscalYearId { get; set; }
    public string? ActiveFiscalYearName { get; set; }
    public int? ActiveWarehouseId { get; set; }
    public string? ActiveWarehouseName { get; set; }
}
