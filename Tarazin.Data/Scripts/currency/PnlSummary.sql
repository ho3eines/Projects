-- =============================================
-- Tarazin.Data/Scripts/currency/PnlSummary.sql
-- Schema: currency
-- Cross-schema: goldshop (سود اجرت/فاکتور از فروش طلا)
-- Query. تفکیک سود و زیان — داشبورد مالی طلا + ارز (PRD §52/§53):
--   سود معاملات طلا / ارز / کالا / تغییر ارزش طلا / تغییر ارزش ارز / اجرت / سکه / آب‌شده / خالص
-- سود محقق‌شده از پاهای معاملات؛ سود محقق‌نشده از اختلاف نرخ جاری با نرخ خرید.
-- =============================================
WITH FxLegs AS (
    SELECT l.LegType, l.ItemKey, ISNULL(l.RealizedPnl, 0) AS Pnl
    FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE (@FromDate IS NULL OR t.TransactionDate >= @FromDate)
      AND (@ToDate IS NULL OR t.TransactionDate <= @ToDate)
)
SELECT N'fx_trade' AS PnlKey, N'سود معاملات ارز (محقق‌شده)' AS Title,
       ROUND(ISNULL((SELECT SUM(Pnl) FROM FxLegs WHERE LegType = N'Currency'), 0), 0) AS Amount
UNION ALL
SELECT N'fx_unreal', N'سود تغییر ارزش ارز (محقق‌نشده)',
       ROUND(ISNULL(SUM(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0)))), 0), 0)
FROM [currency].[Wallets] w
LEFT JOIN [currency].[PriceRates] r
    ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)
UNION ALL
SELECT N'gold_trade', N'سود معاملات طلا/سکه/فلز (محقق‌شده)',
       ROUND(ISNULL((SELECT SUM(Pnl) FROM FxLegs WHERE LegType IN (N'Gold', N'Coin', N'Metal')), 0), 0)
UNION ALL
SELECT N'gold_unreal', N'سود تغییر ارزش طلا/سکه (محقق‌نشده)',
       ROUND(ISNULL(SUM(ISNULL(h.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(h.CostRate, ISNULL(r.SystemRate, 0)))), 0), 0)
FROM [currency].[AssetHoldings] h
JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
UNION ALL
SELECT N'gold_workmanship', N'سود اجرت',
       ROUND(ISNULL((SELECT SUM(ISNULL(s.Workmanship, 0)) FROM [goldshop].[SaleInvoices] s
                     WHERE (@FromDate IS NULL OR s.InvoiceDate >= @FromDate)
                       AND (@ToDate IS NULL OR s.InvoiceDate <= @ToDate)), 0), 0)
UNION ALL
SELECT N'gold_profit', N'سود فروش کالا (فاکتور طلا)',
       ROUND(ISNULL((SELECT SUM(ISNULL(s.Profit, 0)) FROM [goldshop].[SaleInvoices] s
                     WHERE (@FromDate IS NULL OR s.InvoiceDate >= @FromDate)
                       AND (@ToDate IS NULL OR s.InvoiceDate <= @ToDate)), 0), 0)
UNION ALL
SELECT N'gold_coin', N'سود سکه (معاملات ترکیبی)',
       ROUND(ISNULL((SELECT SUM(Pnl) FROM FxLegs WHERE ItemKey IN (N'SIKKEH-EMAMI', N'SIKKEH-BAHAR', N'SIKKEH-NIM', N'SIKKEH-ROB', N'SIKKEH-GRAMI')), 0), 0)
UNION ALL
SELECT N'gold_melted', N'سود آب‌شده (معاملات ترکیبی)',
       ROUND(ISNULL((SELECT SUM(Pnl) FROM FxLegs WHERE ItemKey IN (N'XAU-MELTED', N'XAU-SECOND')), 0), 0)
UNION ALL
SELECT N'net', N'سود خالص',
       ROUND(
         ISNULL((SELECT SUM(Pnl) FROM FxLegs), 0)
         + ISNULL((SELECT SUM(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0))))
                   FROM [currency].[Wallets] w
                   LEFT JOIN [currency].[PriceRates] r
                       ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0)
         + ISNULL((SELECT SUM(ISNULL(h.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(h.CostRate, ISNULL(r.SystemRate, 0))))
                   FROM [currency].[AssetHoldings] h
                   JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
                   LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId), 0)
         + ISNULL((SELECT SUM(ISNULL(s.Workmanship, 0) + ISNULL(s.Profit, 0)) FROM [goldshop].[SaleInvoices] s
                   WHERE (@FromDate IS NULL OR s.InvoiceDate >= @FromDate)
                     AND (@ToDate IS NULL OR s.InvoiceDate <= @ToDate)), 0)
       , 0)
