-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemGroupDelete.sql
-- Schema: inventory
-- Execute. حذف منطقی گروه کالا (در صورت نداشتن کالا).
-- =============================================
IF EXISTS (SELECT 1 FROM [inventory].[Items] WHERE GroupId = @GroupId AND IsDeleted = 0)
    THROW 51031, N'به این گروه کالا متصل است و قابل حذف نیست.', 1;

UPDATE [inventory].[ItemGroups]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE GroupId = @GroupId AND IsDeleted = 0 AND CompanyId = @CompanyId;
