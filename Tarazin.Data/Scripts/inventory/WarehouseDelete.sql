-- Soft-delete a warehouse while preserving movement history.
UPDATE [inventory].[Warehouses]
SET IsDeleted = 1, IsActive = 0
WHERE WarehouseId = @WarehouseId AND IsDeleted = 0;
