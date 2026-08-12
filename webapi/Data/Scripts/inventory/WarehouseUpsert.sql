-- =============================================
-- webapi/Data/Scripts/inventory/WarehouseUpsert.sql
-- Schema: inventory
-- Execute.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [inventory].[Warehouses] WHERE WarehouseId = @WarehouseId)
BEGIN
    INSERT INTO [inventory].[Warehouses] (WarehouseCode, Title, Location, IsActive, CreatedAt)
    VALUES (@WarehouseCode, @Title, @Location, ISNULL(@IsActive, 1), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [inventory].[Warehouses]
    SET WarehouseCode = ISNULL(@WarehouseCode, WarehouseCode),
        Title         = ISNULL(@Title, Title),
        Location      = @Location,
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME()
    WHERE WarehouseId = @WarehouseId;
END
