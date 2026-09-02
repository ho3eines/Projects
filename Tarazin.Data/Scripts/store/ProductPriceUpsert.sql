-- =============================================
-- Tarazin.Data/Scripts/store/ProductPriceUpsert.sql
-- Schema: store
-- Execute. درج/ویرایش قیمت محصول در یک لیست (@PriceId=0 → درج).
-- خطای 51302 = قیمت تکراری (محصول/لیست/فروشگاه).
-- =============================================
IF @PriceId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [store].[ProductPrices]
               WHERE CompanyId = @CompanyId AND PriceListId = @PriceListId
                 AND ProductId = @ProductId
                 AND ISNULL(StoreId, -1) = ISNULL(@StoreId, -1) AND IsDeleted = 0)
        THROW 51302, N'برای این محصول در این لیست/فروشگاه قیمت فعالی وجود دارد.', 1;

    INSERT INTO [store].[ProductPrices]
        (CompanyId, PriceListId, ProductId, StoreId, Price, FromDate, ToDate, MinQty, CreatedBy)
    VALUES
        (@CompanyId, @PriceListId, @ProductId, @StoreId, @Price, @FromDate, @ToDate, ISNULL(@MinQty, 1), @CreatedBy);
END
ELSE
BEGIN
    UPDATE [store].[ProductPrices]
       SET PriceListId = @PriceListId, ProductId = @ProductId, StoreId = @StoreId,
           Price = @Price, FromDate = @FromDate, ToDate = @ToDate, MinQty = ISNULL(@MinQty, 1),
           UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
     WHERE PriceId = @PriceId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51303, N'قیمت یافت نشد.', 1;
END
