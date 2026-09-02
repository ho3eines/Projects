-- =============================================
-- Tarazin.Data/Scripts/store/ProductFullUpsert.sql
-- Schema: store | Cross-schema: inventory
-- Execute. ذخیرهٔ کامل محصول (اطلاعات پایه + قیمت‌ها + SEO).
--   ویژگی‌ها و تنوع‌ها با اسکریپت‌های مجزا مدیریت می‌شوند.
--   ProductId=0 → جدید. کد تکراری → 51032.
-- =============================================
SET NOCOUNT ON;

DECLARE @Code NVARCHAR(50) = LTRIM(RTRIM(ISNULL(@ProductCode, N'')));
DECLARE @Ttl NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@Title, N'')));

IF @Ttl = N''
    THROW 51031, N'نام محصول الزامی است', 1;

IF @Code = N''
    SET @Code = N'P-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(ProductId) FROM [store].[Products]), 0) + 1 AS NVARCHAR(10)), 5);

IF EXISTS (SELECT 1 FROM [store].[Products]
           WHERE ProductCode = @Code AND IsDeleted = 0 AND ProductId <> ISNULL(@ProductId, 0))
    THROW 51032, N'کد محصول تکراری است', 1;

-- کالای انبار باید وجود داشته باشد (وقتی مشخص شده)
IF @ItemCode IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE ItemCode = @ItemCode)
    THROW 51033, N'کالای انبار انتخابی یافت نشد', 1;

IF ISNULL(@ProductId, 0) = 0
BEGIN
    INSERT INTO [store].[Products]
        (ProductCode, SKU, Barcode, Title, ShortTitle, EnglishTitle, CategoryId, BrandId, UnitId,
         ItemCode, Price, OnlinePrice, CostPrice, DiscountPrice, DiscountFrom, DiscountTo,
         Slug, SeoTitle, MetaDescription, LongDescription, Weight, Dimensions,
         StoreId, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (@Code, @SKU, @Barcode, @Ttl, @ShortTitle, @EnglishTitle, @CategoryId, @BrandId, @UnitId,
         @ItemCode, ISNULL(@Price, 0), @OnlinePrice, @CostPrice, @DiscountPrice, @DiscountFrom, @DiscountTo,
         @Slug, @SeoTitle, @MetaDescription, @LongDescription, @Weight, @Dimensions,
         @StoreId, ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CreatedBy, @CompanyId);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
END
ELSE
BEGIN
    UPDATE [store].[Products]
    SET ProductCode = @Code, SKU = @SKU, Barcode = @Barcode,
        Title = @Ttl, ShortTitle = @ShortTitle, EnglishTitle = @EnglishTitle,
        CategoryId = @CategoryId, BrandId = @BrandId, UnitId = @UnitId,
        ItemCode = @ItemCode,
        Price = ISNULL(@Price, Price), OnlinePrice = @OnlinePrice, CostPrice = @CostPrice,
        DiscountPrice = @DiscountPrice, DiscountFrom = @DiscountFrom, DiscountTo = @DiscountTo,
        Slug = @Slug, SeoTitle = @SeoTitle, MetaDescription = @MetaDescription,
        LongDescription = @LongDescription, Weight = @Weight, Dimensions = @Dimensions,
        StoreId = @StoreId, IsActive = ISNULL(@IsActive, IsActive),
        UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
    WHERE ProductId = @ProductId AND CompanyId = @CompanyId AND IsDeleted = 0;

    IF @@ROWCOUNT = 0 THROW 51034, N'محصول یافت نشد یا حذف شده است', 1;
    SELECT @ProductId AS NewId;
END
