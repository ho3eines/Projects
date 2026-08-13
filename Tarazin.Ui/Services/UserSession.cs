using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// Session state for the signed-in user.
///
/// - Web (Blazor Server): scoped → per SignalR circuit.
/// - MAUI (Blazor Hybrid): no circuits → scoped ≈ app-wide singleton
///   (fine for a single-user desktop app).
///
/// Implements <see cref="ICurrentUser"/> so the Data layer can stamp audit
/// rows with the acting user without depending on the UI layer. Also holds
/// the user's effective permission set (RBAC) for UI gating.
/// </summary>
public sealed class UserSession : ICurrentUser
{
    private readonly HashSet<string> _permissions = new(StringComparer.OrdinalIgnoreCase);

    public bool IsAuthenticated { get; private set; }
    public string UserName { get; private set; } = "";
    public string DisplayName { get; private set; } = "کاربر";
    public string Role { get; private set; } = "User";        // کلید نقش (برای سازگاری)
    public string RoleTitle { get; private set; } = "کاربر";  // عنوان فارسی نقش
    public int RoleId { get; private set; }
    public int UserId { get; private set; }

    /// <summary>کلیدهای دسترسی مؤثر کاربر (از نقشش).</summary>
    public IReadOnlyCollection<string> Permissions => _permissions;

    /// <summary>نقش مدیر سیستم — دسترسی به همه‌چیز.</summary>
    public bool IsAdmin => string.Equals(Role, TarazinRoles.Admin, StringComparison.OrdinalIgnoreCase);

    public void SignIn(int userId, string userName, string displayName,
        string roleKey, string roleTitle, int roleId, IEnumerable<string>? permissions = null)
    {
        UserId = userId;
        UserName = userName;
        DisplayName = string.IsNullOrWhiteSpace(displayName) ? userName : displayName;
        Role = string.IsNullOrWhiteSpace(roleKey) ? "User" : roleKey;
        RoleTitle = string.IsNullOrWhiteSpace(roleTitle) ? Role : roleTitle;
        RoleId = roleId;

        _permissions.Clear();
        if (permissions is not null)
        {
            foreach (var p in permissions)
            {
                if (!string.IsNullOrWhiteSpace(p))
                    _permissions.Add(p.Trim());
            }
        }

        IsAuthenticated = true;
    }

    public void SignOut()
    {
        IsAuthenticated = false;
        UserId = 0;
        UserName = "";
        DisplayName = "کاربر";
        Role = "User";
        RoleTitle = "کاربر";
        RoleId = 0;
        _permissions.Clear();
    }

    /// <summary>آیا کاربر دسترسی مشخصی دارد؟ (مدیر همیشه همه را دارد).</summary>
    public bool HasPermission(string permissionKey)
        => IsAuthenticated && !string.IsNullOrWhiteSpace(permissionKey)
           && (IsAdmin || _permissions.Contains(permissionKey));

    /// <summary>آیا کاربر حداقل یکی از دسترسی‌های داده‌شده را دارد؟</summary>
    public bool HasAny(params string[] permissionKeys)
        => permissionKeys.Any(HasPermission);

    /// <summary>آیا کاربر می‌تواند یک ماژول را مشاهده کند؟</summary>
    public bool CanView(string moduleKey)
        => HasPermission(TarazinPermissions.ViewKey(moduleKey));
}
