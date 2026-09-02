-- =============================================
-- Tarazin.Data/Scripts/store/ProductAttributesSync.sql
-- Schema: store
-- Execute. همگام‌سازی ویژگی‌های یک محصول با JSON.
--   @AttributesJson: [{"AttributeId":1,"ValueText":"12GB","SortOrder":0}, ...]
--   Replace-all (Delete+Insert) در یک تراکنش.
-- =============================================
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM [store].[Products] WHERE ProductId = @ProductId AND CompanyId = @CompanyId AND IsDeleted = 0)
    THROW 51034, N'محصول یافت نشد', 1;

BEGIN TRAN;

    DELETE pa FROM [store].[ProductAttributes] pa
    WHERE pa.ProductId = @ProductId;

    INSERT INTO [store].[ProductAttributes] (ProductId, AttributeId, ValueText, SortOrder)
    SELECT @ProductId,
           CAST(JSON_VALUE(j.[value], N'$.AttributeId') AS INT),
           JSON_VALUE(j.[value], N'$.ValueText'),
           CAST(ISNULL(JSON_VALUE(j.[value], N'$.SortOrder'), N'0') AS INT)
    FROM OPENJSON(@AttributesJson) j
    WHERE JSON_VALUE(j.[value], N'$.AttributeId') IS NOT NULL;

COMMIT;

SELECT @@ROWCOUNT AS SyncedCount;
