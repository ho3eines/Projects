-- =============================================
-- Tarazin.Data/Scripts/central/UserRoleBackfill.sql
-- Schema: central
-- Execute. پر کردن RoleId برای کاربران قدیمی از روی ستون Role (رشته‌ای).
-- هر کاربری که نقشش دیگر وجود ندارد به نقش User منتقل می‌شود.
-- =============================================
UPDATE u
SET u.RoleId = r.RoleId
FROM [central].[Users] u
JOIN [central].[Roles] r ON r.RoleKey = u.Role AND r.IsDeleted = 0
WHERE u.RoleId IS NULL AND u.IsDeleted = 0;

UPDATE u
SET u.Role = N'User', u.RoleId = r.RoleId
FROM [central].[Users] u
JOIN [central].[Roles] r ON r.RoleKey = N'User' AND r.IsDeleted = 0
WHERE u.RoleId IS NULL AND u.IsDeleted = 0;

-- اگر باز هم کاربری بدون نقش ماند (نقش User حذف شده بود)، به اولین نقش موجود منتقل شود.
UPDATE u
SET u.Role = r.RoleKey, u.RoleId = r.RoleId
FROM [central].[Users] u
CROSS APPLY (
    SELECT TOP 1 RoleKey, RoleId
    FROM [central].[Roles]
    WHERE IsDeleted = 0
    ORDER BY IsSystem DESC, RoleId
) r
WHERE u.RoleId IS NULL AND u.IsDeleted = 0;
