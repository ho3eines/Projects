-- Soft-delete a warehouse while preserving movement history.
IF EXISTS (SELECT 1 FROM [inventory].[SubWarehouses] WHERE WarehouseId = @WarehouseId AND IsDeleted = 0)
    THROW 51040, N'به این انبار انبارک متصل است؛ ابتدا انبارک‌ها را حذف کنید.', 1;

UPDATE [inventory].[Warehouses]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE WarehouseId = @WarehouseId AND CompanyId = @CompanyId AND IsDeleted = 0;
