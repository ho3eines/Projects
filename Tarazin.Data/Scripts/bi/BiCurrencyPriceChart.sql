-- =============================================
-- Tarazin.Data/Scripts/bi/BiCurrencyPriceChart.sql
-- Schema: bi
-- Cross-schema: currency
-- Query. نمودار قیمت ارز (§55): USD/EUR/AED/GBP/TRY/CNY از تاریخچهٔ نرخ.
-- خروجی: (ChangedAt, ItemKey, Title, NewValue)
-- =============================================
SELECT h.ChangedAt, h.ItemKey, ISNULL(p.Title, h.ItemKey) AS Title, h.NewValue
FROM [currency].[RateHistory] h
LEFT JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
WHERE h.ItemKey IN (N'USD', N'EUR', N'AED', N'GBP', N'TRY', N'CNY')
  AND h.RateKind IN (N'System', N'Online', N'Transaction')
  AND (@FromDate IS NULL OR h.ChangedAt >= @FromDate)
  AND (@ToDate IS NULL OR h.ChangedAt <= @ToDate)
ORDER BY h.ChangedAt;
