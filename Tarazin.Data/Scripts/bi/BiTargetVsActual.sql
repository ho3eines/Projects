-- =============================================
-- Tarazin.Data/Scripts/bi/BiTargetVsActual.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency
-- Query. هدف در برابر عملکرد واقعی (§117) برای دورهٔ انتخابی.
-- خروجی: (TargetKey, Title, TargetAmount, ActualAmount, Variance, VariancePercent, ProgressPercent, Status)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

WITH actual AS (
    SELECT N'Sales' AS TargetKey, ISNULL(SUM(Amt), 0) AS Amount FROM (
        SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart
        UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate >= @MonthStart AND Status = N'Invoiced'
        UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell') s
)
SELECT t.TargetKey, t.Title, t.TargetAmount,
       ISNULL(a.Amount, 0) AS ActualAmount,
       ISNULL(a.Amount, 0) - t.TargetAmount AS Variance,
       CASE WHEN t.TargetAmount = 0 THEN NULL ELSE (ISNULL(a.Amount, 0) - t.TargetAmount) * 100.0 / t.TargetAmount END AS VariancePercent,
       CASE WHEN t.TargetAmount = 0 THEN 0 ELSE ROUND(ISNULL(a.Amount, 0) * 100.0 / t.TargetAmount, 1) END AS ProgressPercent,
       CASE WHEN ISNULL(a.Amount, 0) >= t.TargetAmount THEN N'Good' ELSE N'Bad' END AS Status
FROM [bi].[Targets] t
LEFT JOIN actual a ON a.TargetKey = t.TargetKey
WHERE t.Period = N'Month' AND t.PeriodYear = YEAR(@Today)
  AND ISNULL(t.PeriodMonth, MONTH(@Today)) = MONTH(@Today)
ORDER BY t.TargetKey;
