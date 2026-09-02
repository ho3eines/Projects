-- =============================================
-- Tarazin.Data/Scripts/store/ProductVariantsSync.sql
-- Schema: store
-- Execute. همگام‌سازی تنوع‌های یک محصول با JSON.
--   @VariantsJson: [{"VariantId":0,"VariantCode":"TS-BK-M","Title":"مشکی / M",
--                    "Barcode":null,"Price":250000,"DiscountPrice":null,
--                    "ImageUrl":null,"IsActive":true,"ItemCode":"TS-BK-M",
--                    "Facets":[{"AttributeId":3,"ValueText":"مشکی"},...]}, ...]
--   Replace-all در یک تراکنش + به‌روزرسانی HasVariants محصول.
-- =============================================
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM [store].[Products] WHERE ProductId = @ProductId AND CompanyId = @CompanyId AND IsDeleted = 0)
    THROW 51034, N'محصول یافت نشد', 1;

BEGIN TRAN;

    DELETE va FROM [store].[VariantAttributes] va
    JOIN [store].[ProductVariants] v ON v.VariantId = va.VariantId
    WHERE v.ProductId = @ProductId;

    DELETE FROM [store].[ProductVariants] WHERE ProductId = @ProductId;

    DECLARE @NewVariants TABLE (Idx INT PRIMARY KEY, VariantId INT);

    INSERT INTO [store].[ProductVariants]
        (ProductId, VariantCode, Title, Barcode, Price, DiscountPrice, ImageUrl, IsActive, ItemCode, CreatedAt)
    OUTPUT inserted.VariantId, CAST(JSON_VALUE(j.[key], N'$') AS INT) AS Idx INTO @NewVariants (VariantId, Idx)
    SELECT @ProductId,
           JSON_VALUE(j.[value], N'$.VariantCode'),
           ISNULL(NULLIF(JSON_VALUE(j.[value], N'$.Title'), N''), JSON_VALUE(j.[value], N'$.VariantCode')),
           JSON_VALUE(j.[value], N'$.Barcode'),
           TRY_CONVERT(DECIMAL(18,2), JSON_VALUE(j.[value], N'$.Price')),
           TRY_CONVERT(DECIMAL(18,2), JSON_VALUE(j.[value], N'$.DiscountPrice')),
           JSON_VALUE(j.[value], N'$.ImageUrl'),
           ISNULL(TRY_CONVERT(BIT, JSON_VALUE(j.[value], N'$.IsActive')), 1),
           JSON_VALUE(j.[value], N'$.ItemCode'),
           SYSUTCDATETIME()
    FROM OPENJSON(@VariantsJson) j
    WHERE JSON_VALUE(j.[value], N'$.VariantCode') IS NOT NULL;

    INSERT INTO [store].[VariantAttributes] (VariantId, AttributeId, ValueText)
    SELECT nv.VariantId,
           CAST(JSON_VALUE(f.[value], N'$.AttributeId') AS INT),
           JSON_VALUE(f.[value], N'$.ValueText')
    FROM @NewVariants nv
    JOIN OPENJSON(@VariantsJson) j ON CAST(JSON_VALUE(j.[key], N'$') AS INT) = nv.Idx
    CROSS APPLY OPENJSON(JSON_QUERY(j.[value], N'$.Facets')) f
    WHERE JSON_VALUE(f.[value], N'$.AttributeId') IS NOT NULL;

    UPDATE [store].[Products]
    SET HasVariants = CASE WHEN EXISTS (SELECT 1 FROM [store].[ProductVariants] WHERE ProductId = @ProductId AND IsDeleted = 0)
                           THEN 1 ELSE 0 END
    WHERE ProductId = @ProductId;

COMMIT;

SELECT (SELECT COUNT(*) FROM [store].[ProductVariants] WHERE ProductId = @ProductId AND IsDeleted = 0) AS SyncedCount;
