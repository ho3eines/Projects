-- =============================================
-- Tarazin.Data/Scripts/treasury/CurrencyRateSearch.sql
-- Schema: treasury | Contract: CurrencyRate
-- Query. Shape MUST match CurrencyRateRow (Share) exactly.
-- =============================================
SELECT
    r.RateId,
    r.CurrencyCode,
    r.CurrencyName,
    r.RateToIRR,
    r.RateDate,
    r.CreatedAt,
    r.UpdatedAt
FROM [treasury].[CurrencyRates] r
WHERE r.IsDeleted = 0
  AND (@CompanyId IS NULL OR r.CompanyId = @CompanyId)
ORDER BY r.CurrencyCode
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
