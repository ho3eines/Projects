-- =============================================
-- Tarazin.Data/Scripts/currency/AssetValuation.sql
-- Schema: currency
-- Cross-schema: treasury
-- Query. ارزش لحظه‌ای کل دارایی به ریال (PRD §50/§51):
--   ریال (صندوق/بانک) + کیف پول‌های ارز + طلا/سکه/فلز (دارایی فیزیکی)
-- هر دارایی با واحد اصلی خودش، ارزش‌گذاری بر مبنای نرخ سیستم (§60).
-- =============================================
SELECT N'Cash' AS GroupKey, N'نقد' AS AssetType, N'صندوق ' + c.Title AS Title, N'ریال' AS Unit,
       NULL AS Quantity, NULL AS Rate, c.Balance AS RialValue, NULL AS UnrealizedPnl
FROM [treasury].[CashBoxes] c
WHERE c.IsDeleted = 0 AND c.CompanyId = [central].[fn_MobileCompanyId]() AND c.Balance <> 0

UNION ALL

SELECT N'Cash', N'نقد', N'بانک ' + b.AccountName, N'ریال', NULL, NULL, b.Balance, NULL
FROM [treasury].[BankAccounts] b
WHERE b.IsDeleted = 0 AND b.CompanyId = [central].[fn_MobileCompanyId]() AND b.Balance <> 0

UNION ALL

SELECT N'Currency', N'ارز', cu.CurrencyName, cu.Symbol,
       w.Quantity, r.SystemRate,
       ROUND(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0), 0),
       ROUND(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0))), 0)
FROM [currency].[Wallets] w
JOIN [currency].[Currencies] cu ON cu.CurrencyCode = w.CurrencyCode AND cu.IsDeleted = 0
LEFT JOIN [currency].[PriceRates] r
    ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)
WHERE w.CompanyId = [central].[fn_MobileCompanyId]() AND ISNULL(w.Quantity, 0) <> 0

UNION ALL

SELECT CASE p.ItemType WHEN N'Gold' THEN N'Gold' WHEN N'Coin' THEN N'Coin' ELSE N'Metal' END,
       CASE p.ItemType WHEN N'Gold' THEN N'طلا' WHEN N'Coin' THEN N'سکه' ELSE N'فلز' END,
       h.Title, p.Unit, h.Quantity, r.SystemRate,
       ROUND(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0), 0),
       ROUND(ISNULL(h.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(h.CostRate, ISNULL(r.SystemRate, 0))), 0)
FROM [currency].[AssetHoldings] h
JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE h.CompanyId = [central].[fn_MobileCompanyId]() AND ISNULL(h.Quantity, 0) <> 0

ORDER BY GroupKey, Title;
