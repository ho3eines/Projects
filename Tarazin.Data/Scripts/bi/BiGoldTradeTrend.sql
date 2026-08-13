-- =============================================
-- Tarazin.Data/Scripts/bi/BiGoldTradeTrend.sql
-- Schema: bi
-- Cross-schema: currency, goldshop
-- Query. روند خرید در برابر فروش طلا (§45/§46):
--   ورود (خرید) = پاهای طلا/سکه/فلز با جهت In
--   خروج (فروش) = پاهای Out + فاکتورهای طلافروشی
-- خروجی: سری ماهانه (Value1=خرید, Value2=فروش)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEADD(MONTH, -5, CAST(SYSDATETIME() AS DATE)));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

WITH months AS (
    SELECT TOP (DATEDIFF(MONTH, @From, @To) + 1)
        DATEFROMPARTS(YEAR(DATEADD(MONTH, number, @From)), MONTH(DATEADD(MONTH, number, @From)), 1) AS M
    FROM master..spt_values
    WHERE type = N'P'
    ORDER BY number
),
fx AS (
    SELECT DATEFROMPARTS(YEAR(t.TransactionDate), MONTH(t.TransactionDate), 1) AS M,
           SUM(CASE WHEN l.Direction = N'In' THEN l.AmountRial ELSE 0 END) AS BuyAmt,
           SUM(CASE WHEN l.Direction = N'Out' THEN l.AmountRial ELSE 0 END) AS SellAmt
    FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE l.LegType IN (N'Gold', N'Coin', N'Metal')
      AND t.TransactionDate BETWEEN @From AND @To
    GROUP BY DATEFROMPARTS(YEAR(t.TransactionDate), MONTH(t.TransactionDate), 1)
),
gs AS (
    SELECT DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1) AS M,
           SUM(TotalAmount) AS SellAmt
    FROM [goldshop].[SaleInvoices]
    WHERE InvoiceDate BETWEEN @From AND @To
    GROUP BY DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1)
)
SELECT m.M AS Bucket, FORMAT(m.M, N'yyyy/MM') AS Label,
       ISNULL((SELECT SUM(BuyAmt) FROM fx WHERE M = m.M), 0) AS Value1,
       ISNULL((SELECT SUM(SellAmt) FROM fx WHERE M = m.M), 0) + ISNULL((SELECT SUM(SellAmt) FROM gs WHERE M = m.M), 0) AS Value2,
       0 AS Value3, 0 AS Value4
FROM months m
ORDER BY m.M;
