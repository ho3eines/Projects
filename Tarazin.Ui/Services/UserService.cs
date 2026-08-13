using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// سرویس مدیریت کاربران، نقش‌ها و دسترسی‌ها (RBAC).
///
/// تنها نقطهٔ تماس با [central].[Users] / [central].[Roles] /
/// [central].[Permissions] — صفحات و دیالوگ‌ها به‌جای DbService مستقیم،
/// از این سرویس استفاده می‌کنند تا منطق کاربر (هش رمز، اعتبارسنجی،
/// نقش‌ها) یک‌جا باشد.
/// </summary>
public sealed class UserService
{
    private const string Schema = "central";
    private readonly DbService _db;

    public UserService(DbService db)
    {
        _db = db;
    }

    // ── کاربران ──────────────────────────────────────────────

    public Task<IReadOnlyList<UserRow>> GetUsersAsync(CancellationToken ct = default)
        => _db.QueryAsync<UserRow>(Schema, "UserList", null, ct);

    public Task<UserRow?> GetUserAsync(int userId, CancellationToken ct = default)
        => _db.QueryFirstOrDefaultAsync<UserRow>(Schema, "UserGet", new { UserId = userId }, ct);

    /// <summary>ایجاد کاربر جدید — رمز با PBKDF2 در سمت سرور هش می‌شود.</summary>
    public async Task<int> CreateUserAsync(
        string username, string password, string displayName, string roleKey,
        bool isActive, string? createdBy, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(username))
            throw new ArgumentException("نام کاربری الزامی است.", nameof(username));
        if (string.IsNullOrWhiteSpace(password))
            throw new ArgumentException("رمز عبور الزامی است.", nameof(password));

        return await _db.ExecuteAsync(Schema, "UserUpsert", new
        {
            UserId = 0,
            Username = username.Trim(),
            PasswordHash = PasswordHasher.Hash(password),
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? username.Trim() : displayName.Trim(),
            Role = string.IsNullOrWhiteSpace(roleKey) ? "User" : roleKey,
            IsActive = isActive,
            CreatedBy = createdBy
        }, ct);
    }

    /// <summary>ویرایش کاربر — اگر newPassword خالی باشد رمز تغییر نمی‌کند.</summary>
    public async Task<int> UpdateUserAsync(
        int userId, string? displayName, string? roleKey, bool? isActive,
        string? newPassword, string? updatedBy, CancellationToken ct = default)
    {
        return await _db.ExecuteAsync(Schema, "UserUpsert", new
        {
            UserId = userId,
            Username = (string?)null,
            PasswordHash = string.IsNullOrWhiteSpace(newPassword) ? "" : PasswordHasher.Hash(newPassword),
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? (string?)null : displayName.Trim(),
            Role = string.IsNullOrWhiteSpace(roleKey) ? (string?)null : roleKey,
            IsActive = isActive,
            CreatedBy = updatedBy
        }, ct);
    }

    public Task<int> DeleteUserAsync(int userId, CancellationToken ct = default)
        => _db.ExecuteAsync(Schema, "UserDelete", new { UserId = userId }, ct);

    /// <summary>کلیدهای دسترسی مؤثر کاربر (برای پر کردن نشست ورود).</summary>
    public async Task<IReadOnlyList<string>> GetUserPermissionKeysAsync(int userId, CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync<string>(Schema, "UserPermissions", new { UserId = userId }, ct);
        return rows.ToList();
    }

    // ── نقش‌ها و دسترسی‌ها ──────────────────────────────────

    public Task<IReadOnlyList<RoleRow>> GetRolesAsync(CancellationToken ct = default)
        => _db.QueryAsync<RoleRow>(Schema, "RoleList", null, ct);

    public Task<IReadOnlyList<PermissionRow>> GetPermissionsAsync(CancellationToken ct = default)
        => _db.QueryAsync<PermissionRow>(Schema, "PermissionList", null, ct);

    public async Task<IReadOnlyList<string>> GetRolePermissionKeysAsync(int roleId, CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync<string>(Schema, "RolePermissions", new { RoleId = roleId }, ct);
        return rows.ToList();
    }

    /// <summary>ایجاد/ویرایش نقش + جایگزینی دسترسی‌های آن.</summary>
    public async Task<int> SaveRoleAsync(
        int roleId, string roleKey, string title, string? description,
        IEnumerable<string> permissionKeys, string? createdBy, CancellationToken ct = default)
    {
        return await _db.ExecuteAsync(Schema, "RoleUpsert", new
        {
            RoleId = roleId,
            RoleKey = roleKey.Trim(),
            Title = title.Trim(),
            Description = string.IsNullOrWhiteSpace(description) ? (string?)null : description.Trim(),
            PermissionsJson = System.Text.Json.JsonSerializer.Serialize(permissionKeys),
            CreatedBy = createdBy
        }, ct);
    }

    public Task<int> DeleteRoleAsync(int roleId, CancellationToken ct = default)
        => _db.ExecuteAsync(Schema, "RoleDelete", new { RoleId = roleId }, ct);
}
