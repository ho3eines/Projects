-- =============================================
-- Tarazin.Data/Scripts/bi/BiAssetComposition.sql
-- Schema: bi
-- Cross-schema: treasury, currency, inventory, accounting
-- Query. ترکیب دارایی (§11): نقد/بانک/ارز/طلا/سکه/کالا/مطالبات — ارزش ریالی هر بخش.
-- خروجی: (GroupKey, Title, Value, SecondaryValue=درصد)
-- =============================================
WITH parts AS (
    SELECT N'Cash' AS GroupKey, N'صندوق' AS Title,
           ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0) AS Value
    UNION ALL SELECT N'Bank', N'بانک',
           ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0)
    UNION ALL SELECT N'Currency', N'ارز (کیف پول)',
           ISNULL((SELECT SUM(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0))
                   FROM [currency].[Wallets] w
                   LEFT JOIN [currency].[PriceRates] r
                       ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0)
    UNION ALL SELECT N'Gold', N'طلا',
           ISNULL((SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
                   FROM [currency].[AssetHoldings] h
                   JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
                   LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
                   WHERE p.ItemType = N'Gold'), 0)
    UNION ALL SELECT N'Coin', N'سکه',
           ISNULL((SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
                   FROM [currency].[AssetHoldings] h
                   JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
                   LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
                   WHERE p.ItemType = N'Coin'), 0)
    UNION ALL SELECT N'Metal', N'فلزات گران‌بها',
           ISNULL((SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
                   FROM [currency].[AssetHoldings] h
                   JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
                   LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
                   WHERE p.ItemType = N'Metal'), 0)
    UNION ALL SELECT N'Inventory', N'موجودی کالا',
           ISNULL((SELECT SUM(ISNULL(StockQty, 0) * ISNULL(UnitPrice, 0)) FROM [inventory].[Items] WHERE IsDeleted = 0), 0)
    UNION ALL SELECT N'Receivable', N'مطالبات',
           ISNULL((SELECT SUM(ISNULL(l.Debit, 0) - ISNULL(l.Credit, 0))
                   FROM [accounting].[DocumentLines] l
                   JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
                   WHERE a.AccountType = N'Asset' AND a.IsDeleted = 0
                     AND a.AccountCode NOT IN (N'1000', N'1010', N'1020', N'1030', N'1040')), 0)
)
SELECT GroupKey, Title, Value,
       CASE WHEN (SELECT SUM(Value) FROM parts) = 0 THEN 0
            ELSE ROUND(Value * 100.0 / (SELECT SUM(Value) FROM parts), 1) END AS SecondaryValue
FROM parts
WHERE Value <> 0
ORDER BY Value DESC;
