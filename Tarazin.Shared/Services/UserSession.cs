namespace Tarazin.Services;

/// <summary>
/// Per-circuit session state (Blazor Server).
///
/// In the old architecture every product client received a user token via a
/// URL parameter and every request needed a handshake + AES envelope against
/// the webapi. With a single Blazor Server app there is no cross-process
/// boundary at all: the session simply lives in memory for the lifetime of
/// the SignalR circuit.
/// </summary>
public sealed class UserSession
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
