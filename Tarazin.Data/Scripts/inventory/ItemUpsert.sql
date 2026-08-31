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
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, GroupId, UnitId, StockQty, UnitPrice, IsActive, CreatedAt, CreatedBy, CompanyId,
        SKU, Barcode, Brand, Model, MinStock, MaxStock, ReorderPoint, HasBatch, HasSerial, HasExpiry, LatinTitle, PurchasePrice, SalePrice, Description, ImageUrl)
    VALUES (@EffectiveCode, @ItemTitle, @Category, @Unit, NULLIF(@GroupId, 0), NULLIF(@UnitId, 0), 0, ISNULL(@UnitPrice, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId,
        NULLIF(@SKU, N''), NULLIF(@Barcode, N''), NULLIF(@Brand, N''), NULLIF(@Model, N''),
        ISNULL(@MinStock, 0), ISNULL(@MaxStock, 0), ISNULL(@ReorderPoint, 0),
        ISNULL(@HasBatch, 0), ISNULL(@HasSerial, 0), ISNULL(@HasExpiry, 0),
        NULLIF(@LatinTitle, N''), ISNULL(@PurchasePrice, 0), ISNULL(@SalePrice, 0),
        NULLIF(@Description, N''), NULLIF(@ImageUrl, N''));
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
        SKU       = NULLIF(@SKU, SKU),
        Barcode   = NULLIF(@Barcode, Barcode),
        Brand     = NULLIF(@Brand, Brand),
        Model     = NULLIF(@Model, Model),
        MinStock  = ISNULL(@MinStock, MinStock),
        MaxStock  = ISNULL(@MaxStock, MaxStock),
        ReorderPoint = ISNULL(@ReorderPoint, ReorderPoint),
        HasBatch  = ISNULL(@HasBatch, HasBatch),
        HasSerial = ISNULL(@HasSerial, HasSerial),
        HasExpiry = ISNULL(@HasExpiry, HasExpiry),
        LatinTitle = NULLIF(@LatinTitle, LatinTitle),
        PurchasePrice = ISNULL(@PurchasePrice, PurchasePrice),
        SalePrice = ISNULL(@SalePrice, SalePrice),
        Description = NULLIF(@Description, Description),
        ImageUrl  = NULLIF(@ImageUrl, ImageUrl),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE ItemId = @ItemId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51007, N'کالا یافت نشد.', 1;
END
