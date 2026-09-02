-- =============================================
-- Tarazin.Data/Scripts/store/CouponUpsert.sql
-- Schema: store
-- Execute. درج/ویرایش کد تخفیف (@CouponId=0 → درج).
-- =============================================
IF @CouponId = 0
BEGIN
    IF EXISTS (SELECT 1 FROM [store].[Coupons]
               WHERE CompanyId = @CompanyId AND Code = @Code AND IsDeleted = 0)
        THROW 51320, N'کد تخفیف تکراری است.', 1;

    INSERT INTO [store].[Coupons]
        (CompanyId, Code, Title, StoreId, DiscountType, DiscountValue, MaxDiscount,
         MinOrderTotal, UsageLimit, PerCustomerLimit, FromDate, ToDate, IsActive, CreatedBy)
    VALUES
        (@CompanyId, @Code, @Title, @StoreId, @DiscountType, @DiscountValue, @MaxDiscount,
         ISNULL(@MinOrderTotal, 0), @UsageLimit, @PerCustomerLimit, @FromDate, @ToDate, @IsActive, @CreatedBy);
END
ELSE
BEGIN
    UPDATE [store].[Coupons]
       SET Code = @Code, Title = @Title, StoreId = @StoreId,
           DiscountType = @DiscountType, DiscountValue = @DiscountValue, MaxDiscount = @MaxDiscount,
           MinOrderTotal = ISNULL(@MinOrderTotal, 0), UsageLimit = @UsageLimit, PerCustomerLimit = @PerCustomerLimit,
           FromDate = @FromDate, ToDate = @ToDate, IsActive = @IsActive,
           UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
     WHERE CouponId = @CouponId AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @@ROWCOUNT = 0 THROW 51321, N'کد تخفیف یافت نشد.', 1;
END
