-- =============================================
-- Tarazin.Data/Scripts/bi/BiPurchaseTrend.sql
-- Schema: bi
-- Cross-schema: accounting, currency
-- Query. روند خرید (§32): ماهانه از اسناد خرید + خرید ارز.
-- خروجی: سری (Bucket=ماه, Label, Value1=خرید, Value2=تعداد فاکتور)
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
docs AS (
    SELECT DATEFROMPARTS(YEAR(DocumentDate), MONTH(DocumentDate), 1) AS M,
           TotalAmount AS Amt
    FROM [accounting].[Documents]
    WHERE DocumentType = N'Purchase' AND IsDeleted = 0
      AND DocumentDate BETWEEN @From AND @To
    UNION ALL
    SELECT DATEFROMPARTS(YEAR(TransactionDate), MONTH(TransactionDate), 1),
           TotalRial
    FROM [currency].[FxTransactions]
    WHERE TransactionType = N'Buy' AND TransactionDate BETWEEN @From AND @To
)
SELECT m.M AS Bucket, FORMAT(m.M, 'yyyy/MM') AS Label,
       ISNULL((SELECT SUM(Amt) FROM docs WHERE M = m.M), 0) AS Value1,
       ISNULL((SELECT COUNT(*) FROM docs WHERE M = m.M), 0) AS Value2,
       0 AS Value3, 0 AS Value4
FROM months m
ORDER BY m.M;
