-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldPriceSearch.sql
-- Schema: goldshop | Contract: GoldPrice
-- Query. Shape MUST match GoldPriceRow (Share) exactly.
-- =============================================
SELECT
    p.PriceId,
    p.ItemCode,
    p.Title,
    p.PricePerGram,
    p.RateToIRR,
    p.UpdatedAt
FROM [goldshop].[GoldPrices] p
WHERE p.IsDeleted = 0
ORDER BY p.ItemCode
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
