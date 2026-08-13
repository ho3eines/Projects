-- =============================================
-- Tarazin.Data/Scripts/currency/RateComparison.sql
-- Schema: currency
-- Query. مقایسهٔ نرخ منابع مختلف کنار هم (PRD §59):
--   TabloTala | Matisa | سایر | نرخ سیستم
-- =============================================
SELECT p.ItemType, p.ItemKey, p.Title,
       MAX(CASE WHEN v.SourceKey = N'TABLOTALA' THEN v.Value END) AS TabloRate,
       MAX(CASE WHEN v.SourceKey = N'MATISA'    THEN v.Value END) AS MatisaRate,
       MAX(CASE WHEN v.SourceKey NOT IN (N'TABLOTALA', N'MATISA', N'MANUAL') THEN v.Value END) AS OtherRate,
       r.SystemRate,
       MAX(CASE WHEN v.SourceKey = N'TABLOTALA' THEN v.FetchedAt END) AS TabloAt,
       MAX(CASE WHEN v.SourceKey = N'MATISA'    THEN v.FetchedAt END) AS MatisaAt
FROM [currency].[PriceItems] p
JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
LEFT JOIN [currency].[PriceSourceValues] v ON v.PriceItemId = p.PriceItemId
WHERE p.IsDeleted = 0
  AND (@ItemType IS NULL OR p.ItemType = @ItemType)
GROUP BY p.ItemType, p.ItemKey, p.Title, r.SystemRate
ORDER BY p.ItemType, p.ItemKey;
