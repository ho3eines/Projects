-- =============================================
-- Tarazin.Data/Scripts/bi/BiGoldKarat.sql
-- Schema: bi
-- Cross-schema: currency
-- Query. تحلیل عیار طلا (§41/§48): وزن و ارزش هر عیار از دارایی واقعی.
-- خروجی: ترکیب (GroupKey=ItemKey, Title=عنوان+عیار, Value=ارزش, SecondaryValue=وزن)
-- =============================================
SELECT p.ItemKey AS GroupKey,
       p.Title AS Title,
       ROUND(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0), 0) AS Value,
       ISNULL(h.Quantity, 0) AS SecondaryValue
FROM [currency].[AssetHoldings] h
JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE p.ItemType = N'Gold' AND ISNULL(h.Quantity, 0) <> 0
ORDER BY Value DESC;
