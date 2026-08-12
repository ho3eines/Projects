-- Soft-delete a gold price.
UPDATE [goldshop].[GoldPrices]
SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME()
WHERE PriceId = @PriceId AND IsDeleted = 0;
