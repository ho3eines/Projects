-- =============================================
-- Tarazin.Data/Scripts/central/RolePermissions.sql
-- Schema: central
-- Query. کلیدهای دسترسی یک نقش (برای ویرایشگر نقش).
-- =============================================
SELECT p.PermissionKey
FROM [central].[RolePermissions] rp
JOIN [central].[Permissions] p ON p.PermissionId = rp.PermissionId AND p.IsDeleted = 0
WHERE rp.RoleId = @RoleId
ORDER BY p.PermissionKey;
