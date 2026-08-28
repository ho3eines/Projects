-- =============================================
-- Tarazin.Data/Scripts/inventory/SubWarehouseDelete.sql
-- Schema: inventory
-- Execute. حذف منطقی انبارک (در صورت عدم وجود حرکت).
-- =============================================
IF EXISTS (SELECT 1 FROM [inventory].[Movements] WHERE SubWarehouseId = @SubWarehouseId AND IsDeleted = 0)
    THROW 51036, N'به این انبارک سند متصل است و قابل حذف نیست.', 1;

UPDATE [inventory].[SubWarehouses]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE SubWarehouseId = @SubWarehouseId AND IsDeleted = 0 AND CompanyId = @CompanyId;
