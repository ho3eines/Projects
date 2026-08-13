-- =============================================
-- Tarazin.Data/Scripts/central/RolePermissionSync.sql
-- Schema: central
-- Execute. همگام‌سازی دسترسی‌های یک نقش (idempotent).
-- @RoleKey, @PermissionsJson = [ "accounting.view", "treasury.reports", ... ]
--
-- نقش سیستمی (Admin) همیشه با کاتالوگ C# همگام می‌شود.
-- نقش‌های عادی فقط در اولین اجرا (وقتی هنوز دسترسی ندارند) seed می‌شوند
-- تا سفارشی‌سازی‌های مدیر از طریق UI در ری‌استارت بعدی از بین نرود.
-- =============================================
DECLARE @Rid INT = (SELECT RoleId FROM [central].[Roles] WHERE RoleKey = @RoleKey AND IsDeleted = 0);
IF @Rid IS NULL
    THROW 51060, N'نقش یافت نشد', 1;

DECLARE @IsSys BIT = ISNULL((SELECT IsSystem FROM [central].[Roles] WHERE RoleId = @Rid), 0);

IF @IsSys = 1 OR NOT EXISTS (SELECT 1 FROM [central].[RolePermissions] WHERE RoleId = @Rid)
BEGIN
    DELETE FROM [central].[RolePermissions] WHERE RoleId = @Rid;

    INSERT INTO [central].[RolePermissions] (RoleId, PermissionId)
    SELECT @Rid, p.PermissionId
    FROM OPENJSON(@PermissionsJson) j
    JOIN [central].[Permissions] p ON p.PermissionKey = j.[value] AND p.IsDeleted = 0;
END
