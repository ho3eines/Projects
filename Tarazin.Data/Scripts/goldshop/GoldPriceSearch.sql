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
    p.CreatedAt,
    p.UpdatedAt
FROM [goldshop].[GoldPrices] p
WHERE p.IsDeleted = 0 AND p.CompanyId = @CompanyId
  AND EXISTS (SELECT 1 FROM [goldshop].[GoldItems] i WHERE i.CompanyId=p.CompanyId AND i.ItemCode=p.ItemCode AND i.IsDeleted=0)
ORDER BY p.ItemCode
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
