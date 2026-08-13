-- =============================================
-- Tarazin.Data/Scripts/currency/RateBoard.sql
-- Schema: currency
-- Query. تابلوی مرکز نرخ‌ها و قیمت‌ها — همهٔ انواع نرخ کنار هم (PRD §43/§45/§47/§60).
-- همان منبع داده‌ای که فروش/خرید/ارزش‌گذاری/سود از آن تغذیه می‌شوند.
-- =============================================
SELECT r.RateId, r.PriceItemId, p.ItemType, p.ItemKey, p.Title, p.Unit,
       r.OnlineRate, r.ManualRate, r.SystemRate, r.BuyRate, r.SellRate, r.AccountingRate,
       r.MidRate, r.Spread, r.SourceKey, s.Title AS SourceTitle,
       r.PrevValue, r.ChangePercent, r.ChangeAmount,
       r.IsOverride, r.IsValid, r.Status,
       r.LastFetchAt, r.LastChangeAt, r.RateDate, r.UpdatedAt, r.UpdatedBy
FROM [currency].[PriceRates] r
JOIN [currency].[PriceItems] p ON p.PriceItemId = r.PriceItemId
LEFT JOIN [currency].[PriceSources] s ON s.SourceKey = r.SourceKey
WHERE p.IsDeleted = 0
  AND (@ItemType IS NULL OR p.ItemType = @ItemType)
  AND (@ItemKey IS NULL OR p.ItemKey = @ItemKey)
ORDER BY CASE p.ItemType
             WHEN N'Currency' THEN 1
             WHEN N'Gold' THEN 2
             WHEN N'Coin' THEN 3
             WHEN N'Metal' THEN 4
             ELSE 5
         END, p.Title;
