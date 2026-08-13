-- =============================================
-- Tarazin.Data/Scripts/bi/BiProfitTrend.sql
-- Schema: bi
-- Cross-schema: accounting, goldshop, currency
-- Query. روند سود ماهانه (§9): درآمد/هزینه/سود خالص از دفتر کل (اسناد واقعی)
-- + سود عملیاتی طلا/ارز. خروجی: (Bucket, Label, Value1=درآمد, Value2=هزینه, Value3=سود خالص, Value4=سود طلا/ارز)
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, DATEADD(MONTH, -11, CAST(SYSDATETIME() AS DATE)));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

WITH months AS (
    SELECT TOP (DATEDIFF(MONTH, @From, @To) + 1)
        DATEFROMPARTS(YEAR(DATEADD(MONTH, number, @From)), MONTH(DATEADD(MONTH, number, @From)), 1) AS M
    FROM master..spt_values
    WHERE type = N'P'
    ORDER BY number
),
ledger AS (
    SELECT DATEFROMPARTS(YEAR(d.DocumentDate), MONTH(d.DocumentDate), 1) AS M,
           a.AccountType,
           l.Debit, l.Credit
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0
      AND d.DocumentDate BETWEEN @From AND @To
      AND a.AccountType IN (N'Income', N'Expense')
),
goldfx AS (
    SELECT DATEFROMPARTS(YEAR(t.TransactionDate), MONTH(t.TransactionDate), 1) AS M,
           ISNULL(SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)), 0) AS GoldProfit
    FROM [goldshop].[SaleInvoices]
    WHERE InvoiceDate BETWEEN @From AND @To
    GROUP BY DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1)
    UNION ALL
    SELECT DATEFROMPARTS(YEAR(t.TransactionDate), MONTH(t.TransactionDate), 1),
           ISNULL(SUM(ISNULL(l.RealizedPnl, 0)), 0)
    FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE t.TransactionDate BETWEEN @From AND @To
    GROUP BY DATEFROMPARTS(YEAR(t.TransactionDate), MONTH(t.TransactionDate), 1)
)
SELECT m.M AS Bucket,
       FORMAT(m.M, 'yyyy/MM') AS Label,
       ISNULL((SELECT SUM(Credit) FROM ledger WHERE M = m.M AND AccountType = N'Income'), 0) AS Value1,
       ISNULL((SELECT SUM(Debit) FROM ledger WHERE M = m.M AND AccountType = N'Expense'), 0) AS Value2,
       ISNULL((SELECT SUM(Credit) FROM ledger WHERE M = m.M AND AccountType = N'Income'), 0)
     - ISNULL((SELECT SUM(Debit) FROM ledger WHERE M = m.M AND AccountType = N'Expense'), 0) AS Value3,
       ISNULL((SELECT SUM(GoldProfit) FROM goldfx WHERE M = m.M), 0) AS Value4
FROM months m
ORDER BY m.M;
