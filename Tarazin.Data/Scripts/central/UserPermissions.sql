-- =============================================
-- Tarazin.Data/Scripts/central/UserPermissions.sql
-- Schema: central
-- Query. کلیدهای دسترسی مؤثر یک کاربر (از طریق نقشش) — برای نشست ورود.
-- =============================================
SELECT DISTINCT p.PermissionKey
FROM [central].[Users] u
JOIN [central].[RolePermissions] rp ON rp.RoleId = u.RoleId
JOIN [central].[Permissions] p ON p.PermissionId = rp.PermissionId AND p.IsDeleted = 0
WHERE u.UserId = @UserId AND u.IsDeleted = 0
ORDER BY p.PermissionKey;
