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
///
/// Since a page refresh replaces the circuit (and thus this scoped instance),
/// the session is mirrored to an <see cref="ISessionStore"/> when available so
/// the web host can restore it after the refresh.
/// </summary>
public sealed class UserSession : ICurrentUser
{
    private readonly HashSet<string> _permissions = new(StringComparer.OrdinalIgnoreCase);
    private readonly ISessionStore? _store;

    /// <summary>
    /// <paramref name="store"/> is optional: the web host injects a
    /// browser-storage-backed store; MAUI does not (no persistence).
    /// </summary>
    public UserSession(ISessionStore? store = null) => _store = store;

    /// <summary>Raised when authentication state changes (login/logout/restore).</summary>
    public event Action? Changed;

    public bool IsAuthenticated { get; private set; }
    public string UserName { get; private set; } = "";
    public string DisplayName { get; private set; } = "کاربر";
    public string Role { get; private set; } = "User";        // کلید نقش (برای سازگاری)
    public string RoleTitle { get; private set; } = "کاربر";  // عنوان فارسی نقش
    public int RoleId { get; private set; }
    public int UserId { get; private set; }
    public int? ActiveCompanyId { get; private set; }
    public string? ActiveCompanyName { get; private set; }
    public int? ActiveFiscalYearId { get; private set; }
    public string? ActiveFiscalYearName { get; private set; }

    /// <summary>کلیدهای دسترسی مؤثر کاربر (از نقشش).</summary>
    public IReadOnlyCollection<string> Permissions => _permissions;

    /// <summary>نقش مدیر سیستم — دسترسی به همه‌چیز.</summary>
    public bool IsAdmin => string.Equals(Role, TarazinRoles.Admin, StringComparison.OrdinalIgnoreCase);

    public async Task SignInAsync(int userId, string userName, string displayName,
        string roleKey, string roleTitle, int roleId, IEnumerable<string>? permissions = null,
        int? activeCompanyId = null, string? activeCompanyName = null, int? activeFiscalYearId = null, string? activeFiscalYearName = null)
    {
        Apply(userId, userName, displayName, roleKey, roleTitle, roleId, permissions, activeCompanyId, activeCompanyName, activeFiscalYearId, activeFiscalYearName);

        // نشست را در مرورگر هم ذخیره کن تا با رفرش صفحه از بین نرود.
        if (_store is not null)
        {
            await _store.SaveAsync(new UserSessionData
            {
                UserId = UserId,
                UserName = UserName,
                DisplayName = DisplayName,
                Role = Role,
                RoleTitle = RoleTitle,
                RoleId = RoleId,
                Permissions = _permissions.ToList(),
                ActiveCompanyId = ActiveCompanyId,
                ActiveCompanyName = ActiveCompanyName,
                ActiveFiscalYearId = ActiveFiscalYearId,
                ActiveFiscalYearName = ActiveFiscalYearName
            });
        }
    }

    public async Task UpdateActiveContextAsync(int? companyId, string? companyName, int? fiscalYearId, string? fiscalYearName)
    {
        ActiveCompanyId = companyId;
        ActiveCompanyName = companyName;
        ActiveFiscalYearId = fiscalYearId;
        ActiveFiscalYearName = fiscalYearName;

        if (_store is not null && IsAuthenticated)
        {
            var data = await _store.LoadAsync();
            if (data is not null)
            {
                data.ActiveCompanyId = companyId;
                data.ActiveCompanyName = companyName;
                data.ActiveFiscalYearId = fiscalYearId;
                data.ActiveFiscalYearName = fiscalYearName;
                await _store.SaveAsync(data);
            }
        }

        Changed?.Invoke();
    }

    /// <summary>
    /// بازیابی نشست ذخیره‌شده در مرورگر (بعد از رفرش/قطع circuit). اگر نشستی
    /// ذخیره نشده باشد یا استوری وجود نداشته باشد، هیچ کاری نمی‌کند.
    /// </summary>
    public async Task RestoreAsync(CancellationToken ct = default)
    {
        if (_store is null || IsAuthenticated)
            return;

        var data = await _store.LoadAsync(ct);
        if (data is null)
            return;

        Apply(data.UserId, data.UserName, data.DisplayName,
            data.Role, data.RoleTitle, data.RoleId, data.Permissions,
            data.ActiveCompanyId, data.ActiveCompanyName, data.ActiveFiscalYearId, data.ActiveFiscalYearName);
    }

    public async Task SignOutAsync()
    {
        IsAuthenticated = false;
        UserId = 0;
        UserName = "";
        DisplayName = "کاربر";
        Role = "User";
        RoleTitle = "کاربر";
        RoleId = 0;
        ActiveCompanyId = null;
        ActiveCompanyName = null;
        ActiveFiscalYearId = null;
        ActiveFiscalYearName = null;
        _permissions.Clear();
        Changed?.Invoke();

        if (_store is not null)
            await _store.ClearAsync();
    }

    private void Apply(int userId, string userName, string displayName,
        string roleKey, string roleTitle, int roleId, IEnumerable<string>? permissions,
        int? activeCompanyId = null, string? activeCompanyName = null, int? activeFiscalYearId = null, string? activeFiscalYearName = null)
    {
        UserId = userId;
        UserName = userName;
        DisplayName = string.IsNullOrWhiteSpace(displayName) ? userName : displayName;
        Role = string.IsNullOrWhiteSpace(roleKey) ? "User" : roleKey;
        RoleTitle = string.IsNullOrWhiteSpace(roleTitle) ? Role : roleTitle;
        RoleId = roleId;
        ActiveCompanyId = activeCompanyId;
        ActiveCompanyName = activeCompanyName;
        ActiveFiscalYearId = activeFiscalYearId;
        ActiveFiscalYearName = activeFiscalYearName;

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
        Changed?.Invoke();
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
