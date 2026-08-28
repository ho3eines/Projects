-- =============================================
-- Tarazin.Data/Scripts/treasury/CurrencyRateUpsert.sql
-- Schema: treasury | Contract: CurrencyRate (producer)
-- Execute. RateId=0 identifies a new record; every non-zero id is an edit.
-- =============================================
IF @RateId = 0
BEGIN
    INSERT INTO [treasury].[CurrencyRates] (CurrencyCode, CurrencyName, RateToIRR, RateDate, CreatedAt, UpdatedAt, CompanyId)
    VALUES (@CurrencyCode, @CurrencyName, @RateToIRR, ISNULL(@RateDate, CAST(SYSDATETIME() AS DATE)), SYSUTCDATETIME(), SYSUTCDATETIME(), @CompanyId);
END
ELSE
BEGIN
    UPDATE [treasury].[CurrencyRates]
    SET CurrencyCode = @CurrencyCode,
        CurrencyName = ISNULL(@CurrencyName, CurrencyName),
        RateToIRR    = @RateToIRR,
        RateDate     = ISNULL(@RateDate, RateDate),
        UpdatedAt    = SYSUTCDATETIME()
    WHERE RateId = @RateId AND (@CompanyId IS NULL OR CompanyId = @CompanyId);
END
