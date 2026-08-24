-- =============================================
-- Tarazin.Data/Scripts/currency/WalletList.sql
-- Schema: currency
-- Query. کیف پول و موجودی هر ارز (PRD §36) — موجودی، نرخ خرید، نرخ فروش،
-- نرخ متوسط خرید، ارزش ریالی، سود/زیان ارزی، گردش دوره (§52).
-- =============================================
SELECT w.CurrencyCode,
       c.CurrencyName,
       ISNULL(c.Symbol, N'') AS Symbol,
       w.Quantity,
       w.AvgBuyRate,
       ISNULL(r.SystemRate, 0) AS SystemRate,
       ISNULL(r.BuyRate, 0)   AS BuyRate,
       ISNULL(r.SellRate, 0)  AS SellRate,
       ROUND(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0), 0) AS RialValue,
       ROUND(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0))), 0) AS UnrealizedPnl,
       -- موجودی اول دوره = موجودی فعلی − ورود + خروج در بازه
       ROUND(ISNULL(w.Quantity, 0) - ISNULL(m.InQty, 0) + ISNULL(m.OutQty, 0), 4) AS OpeningQty,
       ISNULL(w.OpeningAvgRate, 0) AS OpeningAvgRate,
       ISNULL(m.InQty, 0) AS InQty,
       ISNULL(m.OutQty, 0) AS OutQty,
       w.LastMovementAt
FROM [currency].[Wallets] w
JOIN [currency].[Currencies] c ON c.CurrencyCode = w.CurrencyCode AND c.IsDeleted = 0
LEFT JOIN [currency].[PriceRates] r
    ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)
LEFT JOIN (
    SELECT CurrencyCode,
           SUM(CASE WHEN Direction = N'In'  THEN Quantity ELSE 0 END) AS InQty,
           SUM(CASE WHEN Direction = N'Out' THEN Quantity ELSE 0 END) AS OutQty
    FROM [currency].[CurrencyMovements]
    WHERE (@FromDate IS NULL OR MovementDate >= @FromDate)
      AND (@ToDate IS NULL OR MovementDate <= @ToDate)
      AND CompanyId = [central].[fn_MobileCompanyId]()
    GROUP BY CurrencyCode
) m ON m.CurrencyCode = w.CurrencyCode
WHERE c.IsActive = 1
  AND w.CompanyId = [central].[fn_MobileCompanyId]()
  AND (@OnlyNonZero = 0 OR ISNULL(w.Quantity, 0) <> 0)
ORDER BY RialValue DESC, w.CurrencyCode;
