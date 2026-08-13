-- Soft-delete a gold item and its current price while preserving history.
DECLARE @ItemCode NVARCHAR(50) =
    (SELECT ItemCode FROM [goldshop].[GoldItems] WHERE GoldItemId = @GoldItemId AND IsDeleted = 0);

UPDATE [goldshop].[GoldItems]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE GoldItemId = @GoldItemId AND IsDeleted = 0;

UPDATE [goldshop].[GoldPrices]
SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME()
WHERE ItemCode = @ItemCode AND IsDeleted = 0;
