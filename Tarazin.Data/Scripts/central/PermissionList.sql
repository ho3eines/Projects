-- =============================================
-- Tarazin.Data/Scripts/central/PermissionList.sql
-- Schema: central
-- Query. فهرست تمام دسترسی‌ها (برای ویرایشگر نقش).
-- =============================================
SELECT
    p.PermissionId,
    p.PermissionKey,
    p.Title,
    p.ModuleKey,
    p.IsDeleted,
    p.CreatedAt,
    p.UpdatedAt
FROM [central].[Permissions] p
WHERE p.IsDeleted = 0
ORDER BY p.ModuleKey, p.PermissionKey;
