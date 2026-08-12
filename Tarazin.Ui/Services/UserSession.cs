using Tarazin.Data;

namespace Tarazin.Services;

/// <summary>
/// Session state for the signed-in user.
///
/// - Web (Blazor Server): scoped → per SignalR circuit.
/// - MAUI (Blazor Hybrid): no circuits → scoped ≈ app-wide singleton
///   (fine for a single-user desktop app).
///
/// Implements <see cref="ICurrentUser"/> so the Data layer can stamp audit
/// rows with the acting user without depending on the UI layer.
/// </summary>
public sealed class UserSession : ICurrentUser
{
    public bool IsAuthenticated { get; private set; }
    public string UserName { get; private set; } = "";
    public string DisplayName { get; private set; } = "کاربر";
    public string Role { get; private set; } = "User";
    public int UserId { get; private set; }

    public bool IsAdmin => string.Equals(Role, "Admin", StringComparison.OrdinalIgnoreCase);

    public void SignIn(int userId, string userName, string displayName, string role)
    {
        UserId = userId;
        UserName = userName;
        DisplayName = string.IsNullOrWhiteSpace(displayName) ? userName : displayName;
        Role = string.IsNullOrWhiteSpace(role) ? "User" : role;
        IsAuthenticated = true;
    }

    public void SignOut()
    {
        IsAuthenticated = false;
        UserId = 0;
        UserName = "";
        DisplayName = "کاربر";
        Role = "User";
    }
}
