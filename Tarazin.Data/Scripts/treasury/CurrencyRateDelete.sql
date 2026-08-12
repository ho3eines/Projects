-- Soft-delete a currency rate.
UPDATE [treasury].[CurrencyRates]
SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME()
WHERE RateId = @RateId AND IsDeleted = 0;
