-- =============================================
-- Tarazin.Data/Scripts/bi/BiBranchKpis.sql
-- Schema: bi
-- Cross-schema: branch, goldshop, store
-- Query. داشبورد شعب (§86–§88): فروش هر شعبه از فاکتورهای طلا و فروشگاه
-- (BranchId روی فاکتورها — در حال حاضر همهٔ فاکتورها بدون شعبه‌اند؛ با افزودن
-- BranchId به فاکتورها، این گزارش به‌صورت خودکار پر می‌شود — Backlog B14).
-- خروجی: جدول (Col1=شعبه, Col2=فروش طلا, Col3=فروش فروشگاه, Col4=مجموع, Amount=مجموع)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

SELECT b.BranchCode AS RowKey,
       b.Title AS Col1,
       FORMAT(ISNULL((SELECT SUM(s.TotalAmount) FROM [goldshop].[SaleInvoices] s
                      WHERE s.BranchId = b.BranchId AND s.InvoiceDate >= @MonthStart), 0), 'N0') AS Col2,
       FORMAT(ISNULL((SELECT SUM(o.TotalAmount) FROM [store].[Orders] o
                      WHERE o.BranchId = b.BranchId AND o.OrderDate >= @MonthStart AND o.Status = N'Invoiced'), 0), 'N0') AS Col3,
       N'—' AS Col4,
       CAST(ISNULL((SELECT SUM(s.TotalAmount) FROM [goldshop].[SaleInvoices] s
                    WHERE s.BranchId = b.BranchId AND s.InvoiceDate >= @MonthStart), 0)
          + ISNULL((SELECT SUM(o.TotalAmount) FROM [store].[Orders] o
                    WHERE o.BranchId = b.BranchId AND o.OrderDate >= @MonthStart AND o.Status = N'Invoiced'), 0) AS DECIMAL(18,2)) AS Amount,
       0 AS SecondaryAmount,
       NULL AS Date1,
       N'/bi/branches' AS Link
FROM [branch].[Branches] b
WHERE b.IsDeleted = 0 AND b.IsActive = 1
ORDER BY b.BranchCode;
