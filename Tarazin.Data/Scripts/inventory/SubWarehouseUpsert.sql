-- =============================================
-- Tarazin.Data/Scripts/inventory/SubWarehouseUpsert.sql
-- Schema: inventory
-- Execute. ثبت/ویرایش انبارک. SubWarehouseId=0 یعنی رکورد جدید.
-- =============================================
IF @WarehouseId IS NULL OR @WarehouseId = 0
    THROW 51034, N'انبار اصلی انتخاب نشده است.', 1;

DECLARE @EffectiveCode NVARCHAR(50) = ISNULL(NULLIF(@SubWarehouseCode, N''),
    N'SUB-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(SubWarehouseId) FROM [inventory].[SubWarehouses] WHERE CompanyId = @CompanyId), 0) + 1 AS NVARCHAR(10)), 5));

IF @SubWarehouseId = 0
BEGIN
    INSERT INTO [inventory].[SubWarehouses] (WarehouseId, SubWarehouseCode, Title, Location, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@WarehouseId, @EffectiveCode, @Title, @Location, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [inventory].[SubWarehouses]
    SET WarehouseId      = @WarehouseId,
        SubWarehouseCode = ISNULL(@SubWarehouseCode, SubWarehouseCode),
        Title            = ISNULL(@Title, Title),
        Location         = @Location,
        IsActive         = ISNULL(@IsActive, IsActive),
        UpdatedAt        = SYSUTCDATETIME(),
        UpdatedBy        = @CreatedBy
    WHERE SubWarehouseId = @SubWarehouseId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51035, N'انبارک یافت نشد.', 1;
END
