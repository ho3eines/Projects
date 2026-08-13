-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldRateBoard.sql
-- Schema: goldshop
-- Cross-schema: currency (مرکز نرخ‌ها و قیمت‌ها — PRD §54/§60)
-- Query. تابلوی نرخ طلا از «مرکز قیمت واحد» برای فرم فروش طلا:
--   کاربر نرخ آنلاین/سیستم را می‌بیند و با یک کلیک در فاکتور قرار می‌دهد.
-- =============================================
SELECT p.ItemKey, p.Title, p.Unit,
       r.OnlineRate, r.SystemRate, r.BuyRate, r.SellRate, r.AccountingRate,
       r.LastFetchAt, r.LastChangeAt, r.SourceKey,
       ISNULL(r.IsValid, 0) AS IsValid
FROM [currency].[PriceItems] p
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE p.ItemType = @ItemType AND p.IsDeleted = 0
ORDER BY p.Title;
