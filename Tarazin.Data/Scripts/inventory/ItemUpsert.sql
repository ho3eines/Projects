-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemUpsert.sql
-- Schema: inventory
-- Execute. ثبت/ویرایش کالا (با گروه و واحد).
-- =============================================
DECLARE @EffectiveCode NVARCHAR(50) = ISNULL(NULLIF(@ItemCode, N''),
    N'ITM-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(ItemId) FROM [inventory].[Items] WHERE CompanyId = @CompanyId), 0) + 1 AS NVARCHAR(10)), 5));

-- ItemId=0 identifies a new record; every non-zero id is an edit.
IF @ItemId = 0
BEGIN
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, GroupId, UnitId, StockQty, UnitPrice, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES (@EffectiveCode, @ItemTitle, @Category, @Unit, NULLIF(@GroupId, 0), NULLIF(@UnitId, 0), 0, ISNULL(@UnitPrice, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END
ELSE
BEGIN
    UPDATE [inventory].[Items]
    SET ItemCode  = ISNULL(@ItemCode, ItemCode),
        ItemTitle = ISNULL(@ItemTitle, ItemTitle),
        Category  = @Category,
        Unit      = ISNULL(@Unit, Unit),
        GroupId   = NULLIF(@GroupId, 0),
        UnitId    = NULLIF(@UnitId, 0),
        UnitPrice = @UnitPrice,
        IsActive  = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE ItemId = @ItemId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51007, N'کالا یافت نشد.', 1;
END
