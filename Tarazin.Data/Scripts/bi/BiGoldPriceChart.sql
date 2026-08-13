-- =============================================
-- Tarazin.Data/Scripts/bi/BiGoldPriceChart.sql
-- Schema: bi
-- Cross-schema: currency
-- Query. نمودار قیمت طلا (§44): ۱۸/۲۴ عیار، مثقال، انس — از تاریخچهٔ نرخ واقعی.
-- خروجی: (ChangedAt, ItemKey, Title, NewValue)
-- =============================================
SELECT h.ChangedAt, h.ItemKey, ISNULL(p.Title, h.ItemKey) AS Title, h.NewValue
FROM [currency].[RateHistory] h
LEFT JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
WHERE h.ItemKey IN (N'XAU-18', N'XAU-24', N'MISGHAL', N'OUNCE')
  AND h.RateKind IN (N'System', N'Online', N'Transaction')
  AND (@FromDate IS NULL OR h.ChangedAt >= @FromDate)
  AND (@ToDate IS NULL OR h.ChangedAt <= @ToDate)
ORDER BY h.ChangedAt;
