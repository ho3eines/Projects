-- =============================================
-- Tarazin.Data/Scripts/inventory/WarehouseUpsert.sql
-- Schema: inventory
-- Execute. ثبت/ویرایش انبار (با شرکت فعال).
-- =============================================
DECLARE @EffectiveCode NVARCHAR(30) = ISNULL(NULLIF(@WarehouseCode, N''),
    N'WH-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(WarehouseId) FROM [inventory].[Warehouses] WHERE CompanyId = @CompanyId), 0) + 1 AS NVARCHAR(10)), 5));

-- WarehouseId=0 identifies a new record; every non-zero id is an edit.
IF @WarehouseId = 0
BEGIN
    INSERT INTO [inventory].[Warehouses] (WarehouseCode, Title, Location, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@EffectiveCode, @Title, @Location, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [inventory].[Warehouses]
    SET WarehouseCode = ISNULL(@WarehouseCode, WarehouseCode),
        Title         = ISNULL(@Title, Title),
        Location      = @Location,
        IsActive      = ISNULL(@IsActive, IsActive),
        UpdatedAt     = SYSUTCDATETIME(),
        UpdatedBy     = @CreatedBy
    WHERE WarehouseId = @WarehouseId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51008, N'انبار یافت نشد.', 1;
END
