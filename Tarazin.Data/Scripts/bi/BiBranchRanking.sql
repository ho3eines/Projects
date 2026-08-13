-- =============================================
-- Tarazin.Data/Scripts/bi/BiBranchRanking.sql
-- Schema: bi
-- Cross-schema: branch, goldshop
-- Query. رتبه‌بندی شعب (§87) بر اساس دادهٔ ثبت‌شده (فروش ماه).
-- تا وقتی BranchId به فاکتورها متصل نشده، فقط فهرست شعب نمایش داده می‌شود.
-- خروجی: جدول (Col1=رتبه, Col2=شعبه, Col3=فروش ماه, Col4=مدیر, Amount=فروش)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

SELECT b.BranchCode AS RowKey,
       ROW_NUMBER() OVER (ORDER BY ISNULL(Sales.Amt, 0) DESC) AS Col1,
       b.Title AS Col2,
       FORMAT(ISNULL(Sales.Amt, 0), 'N0') AS Col3,
       ISNULL(b.Manager, N'—') AS Col4,
       CAST(ISNULL(Sales.Amt, 0) AS DECIMAL(18,2)) AS Amount,
       0 AS SecondaryAmount,
       NULL AS Date1,
       N'/bi/branches' AS Link
FROM [branch].[Branches] b
LEFT JOIN (
    SELECT BranchId, SUM(TotalAmount) AS Amt
    FROM [goldshop].[SaleInvoices]
    WHERE InvoiceDate >= @MonthStart
    GROUP BY BranchId
) Sales ON Sales.BranchId = b.BranchId
WHERE b.IsDeleted = 0 AND b.IsActive = 1
ORDER BY Amount DESC;
