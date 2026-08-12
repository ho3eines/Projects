-- =============================================
-- HermesApp/Data/Scripts/treasury/CurrencyRateUpsert.sql
-- Schema: treasury | Contract: CurrencyRate (producer)
-- Execute. Idempotent upsert on CurrencyCode.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [treasury].[CurrencyRates] WHERE CurrencyCode = @CurrencyCode)
BEGIN
    INSERT INTO [treasury].[CurrencyRates] (CurrencyCode, CurrencyName, RateToIRR, RateDate, UpdatedAt)
    VALUES (@CurrencyCode, @CurrencyName, @RateToIRR, ISNULL(@RateDate, CAST(SYSDATETIME() AS DATE)), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [treasury].[CurrencyRates]
    SET CurrencyName = ISNULL(@CurrencyName, CurrencyName),
        RateToIRR    = @RateToIRR,
        RateDate     = ISNULL(@RateDate, RateDate),
        UpdatedAt    = SYSUTCDATETIME()
    WHERE CurrencyCode = @CurrencyCode;
END
