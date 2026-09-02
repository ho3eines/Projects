-- =============================================
-- Tarazin.Data/Scripts/store/PromotionUpsert.sql
-- Schema: store
-- Execute. درج/ویرایش کمپین تخفیف (@PromotionId=0 → درج).
-- =============================================
IF @PromotionId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [store].[Promotions]
               WHERE CompanyId = @CompanyId AND Code = @Code AND IsDeleted = 0)
        THROW 51310, N'کد کمپین تکراری است.', 1;

    INSERT INTO [store].[Promotions]
        (CompanyId, Code, Title, StoreId, ProductId, CategoryId,
         DiscountType, DiscountValue, FromDate, ToDate, MinOrderTotal, IsActive, CreatedBy)
    VALUES
        (@CompanyId, @Code, @Title, @StoreId, @ProductId, @CategoryId,
         @DiscountType, @DiscountValue, @FromDate, @ToDate, ISNULL(@MinOrderTotal, 0), @IsActive, @CreatedBy);
END
ELSE
BEGIN
    UPDATE [store].[Promotions]
       SET Code = @Code, Title = @Title, StoreId = @StoreId, ProductId = @ProductId, CategoryId = @CategoryId,
           DiscountType = @DiscountType, DiscountValue = @DiscountValue,
           FromDate = @FromDate, ToDate = @ToDate, MinOrderTotal = ISNULL(@MinOrderTotal, 0),
           IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
     WHERE PromotionId = @PromotionId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51311, N'کمپین یافت نشد.', 1;
END
