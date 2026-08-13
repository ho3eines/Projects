-- =============================================
-- Tarazin.Data/Scripts/inventory/WarehouseUpsert.sql
-- Schema: inventory
-- Execute.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(30) = ISNULL(NULLIF(@WarehouseCode, N''),
    N'WH-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(WarehouseId) FROM [inventory].[Warehouses]), 0) + 1 AS NVARCHAR(10)), 5));

-- WarehouseId=0 identifies a new record; every non-zero id is an edit.
IF @WarehouseId = 0
BEGIN
    INSERT INTO [inventory].[Warehouses] (WarehouseCode, Title, Location, IsActive, CreatedAt)
    VALUES (@EffectiveCode, @Title, @Location, ISNULL(@IsActive, 1), SYSUTCDATETIME());
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
