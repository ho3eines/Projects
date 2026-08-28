-- =============================================
-- Tarazin.Data/Scripts/inventory/UnitDelete.sql
-- Schema: inventory
-- Execute. حذف منطقی واحد کالا (در صورت عدم استفاده).
-- =============================================
IF EXISTS (SELECT 1 FROM [inventory].[Items] WHERE UnitId = @UnitId AND IsDeleted = 0)
    THROW 51033, N'این واحد توسط کالا استفاده می‌شود و قابل حذف نیست.', 1;

UPDATE [inventory].[Units]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE UnitId = @UnitId AND IsDeleted = 0 AND CompanyId = @CompanyId;
