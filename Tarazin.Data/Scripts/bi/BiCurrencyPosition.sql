-- =============================================
-- Tarazin.Data/Scripts/bi/BiCurrencyPosition.sql
-- Schema: bi
-- Cross-schema: currency
-- Query. وضعیت دارایی ارزی (§57): ارز | مقدار | نرخ فعلی | ارزش ریالی | سود/زیان.
-- خروجی: جدول تحلیلی (Col1=ارز, Col2=نرخ, Col3=ارزش, Col4=سود/زیان, Amount=ارزش ریالی)
-- =============================================
SELECT w.CurrencyCode AS RowKey,
       cu.CurrencyName AS Col1,
       FORMAT(ISNULL(r.SystemRate, 0), 'N0') AS Col2,
       FORMAT(ROUND(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0), 0), 'N0') AS Col3,
       FORMAT(ROUND(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0))), 0), 'N0') AS Col4,
       CAST(ROUND(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0), 0) AS DECIMAL(18,2)) AS Amount,
       ROUND(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0))), 0) AS SecondaryAmount,
       NULL AS Date1, N'/currency/wallets' AS Link
FROM [currency].[Wallets] w
JOIN [currency].[Currencies] cu ON cu.CurrencyCode = w.CurrencyCode AND cu.IsDeleted = 0
LEFT JOIN [currency].[PriceRates] r
    ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)
WHERE ISNULL(w.Quantity, 0) <> 0
ORDER BY Amount DESC;
