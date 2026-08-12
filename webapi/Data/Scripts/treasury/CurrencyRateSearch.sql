-- =============================================
-- webapi/Data/Scripts/treasury/CurrencyRateSearch.sql
-- Schema: treasury | Contract: CurrencyRate
-- Query. Shape MUST match CurrencyRateRow (Share) exactly.
-- =============================================
SELECT
    r.RateId,
    r.CurrencyCode,
    r.CurrencyName,
    r.RateToIRR,
    r.RateDate,
    r.UpdatedAt
FROM [treasury].[CurrencyRates] r
ORDER BY r.CurrencyCode
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
