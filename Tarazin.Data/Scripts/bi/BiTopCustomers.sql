-- =============================================
-- Tarazin.Data/Scripts/bi/BiTopCustomers.sql
-- Schema: bi
-- Cross-schema: goldshop, store
-- Query. Top Customers (§29/§85): مشتریان بر اساس خرید واقعی.
-- خروجی: جدول (Col1=نام, Col2=تعداد خرید, Col3=آخرین خرید, Col4=میانگین, Amount=مجموع)
-- =============================================
SELECT TOP (@TakeSize) * FROM (
    SELECT s.CustomerName AS RowKey, s.CustomerName AS Col1,
           FORMAT(COUNT(*), 'N0') AS Col2,
           CONVERT(NVARCHAR(10), MAX(s.InvoiceDate), 111) AS Col3,
           FORMAT(ROUND(AVG(s.TotalAmount), 0), 'N0') AS Col4,
           CAST(SUM(s.TotalAmount) AS DECIMAL(18,2)) AS Amount,
           CAST(SUM(ISNULL(s.Workmanship, 0) + ISNULL(s.Profit, 0)) AS DECIMAL(18,2)) AS SecondaryAmount,
           MAX(s.InvoiceDate) AS Date1,
           N'/goldshop/reports' AS Link
    FROM [goldshop].[SaleInvoices] s
    WHERE s.CustomerName IS NOT NULL AND s.CustomerName <> N''
    GROUP BY s.CustomerName
    UNION ALL
    SELECT o.CustomerName, o.CustomerName,
           FORMAT(COUNT(*), 'N0'),
           CONVERT(NVARCHAR(10), MAX(o.OrderDate), 111),
           FORMAT(ROUND(AVG(o.TotalAmount), 0), 'N0'),
           CAST(SUM(o.TotalAmount) AS DECIMAL(18,2)),
           CAST(SUM(o.TotalAmount) * 0.10 AS DECIMAL(18,2)),
           MAX(o.OrderDate),
           N'/store/reports'
    FROM [store].[Orders] o
    WHERE o.Status = N'Invoiced' AND o.CustomerName IS NOT NULL
    GROUP BY o.CustomerName
) t
ORDER BY t.Amount DESC;
