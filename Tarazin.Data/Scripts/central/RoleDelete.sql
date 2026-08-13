-- =============================================
-- Tarazin.Data/Scripts/central/RoleDelete.sql
-- Schema: central
-- Execute. حذف منطقی نقش. نقش سیستمی یا نقش دارای کاربر قابل حذف نیست.
-- =============================================
IF EXISTS (SELECT 1 FROM [central].[Roles] WHERE RoleId = @RoleId AND IsSystem = 1 AND IsDeleted = 0)
    THROW 51062, N'نقش سیستمی قابل حذف نیست', 1;

IF EXISTS (SELECT 1 FROM [central].[Users] WHERE RoleId = @RoleId AND IsDeleted = 0)
    THROW 51063, N'نقش به کاربرانی تخصیص یافته است؛ ابتدا کاربران را به نقش دیگری منتقل کنید', 1;

DELETE FROM [central].[RolePermissions] WHERE RoleId = @RoleId;

UPDATE [central].[Roles]
SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME()
WHERE RoleId = @RoleId AND IsSystem = 0 AND IsDeleted = 0;
