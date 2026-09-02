-- =============================================
-- Tarazin.Data/Scripts/store/ProductImagesSync.sql
-- Schema: store
-- Execute. همگام‌سازی تصاویر محصول با JSON (Replace-all).
--   @ImagesJson: [{"ImageUrl":"...","AltText":"...","SortOrder":0,"IsMain":true}, ...]
--   MainImageUrl محصول هم با تصویر IsMain=1 همگام می‌شود.
-- =============================================
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM [store].[Products] WHERE ProductId = @ProductId AND CompanyId = @CompanyId AND IsDeleted = 0)
    THROW 51034, N'محصول یافت نشد', 1;

BEGIN TRAN;

    DELETE FROM [store].[ProductImages] WHERE ProductId = @ProductId;

    INSERT INTO [store].[ProductImages] (ProductId, ImageUrl, AltText, SortOrder, IsMain, CreatedAt)
    SELECT @ProductId,
           JSON_VALUE(j.[value], N'$.ImageUrl'),
           JSON_VALUE(j.[value], N'$.AltText'),
           CAST(ISNULL(JSON_VALUE(j.[value], N'$.SortOrder'), N'0') AS INT),
           ISNULL(TRY_CONVERT(BIT, JSON_VALUE(j.[value], N'$.IsMain')), 0),
           SYSUTCDATETIME()
    FROM OPENJSON(@ImagesJson) j
    WHERE JSON_VALUE(j.[value], N'$.ImageUrl') IS NOT NULL;

    UPDATE p
    SET p.MainImageUrl = (SELECT TOP 1 i.ImageUrl FROM [store].[ProductImages] i
                          WHERE i.ProductId = p.ProductId
                          ORDER BY i.IsMain DESC, i.SortOrder, i.ImageId)
    FROM [store].[Products] p
    WHERE p.ProductId = @ProductId;

COMMIT;

SELECT (SELECT COUNT(*) FROM [store].[ProductImages] WHERE ProductId = @ProductId) AS SyncedCount;
