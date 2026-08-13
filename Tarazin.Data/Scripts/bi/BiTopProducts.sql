-- =============================================
-- Tarazin.Data/Scripts/bi/BiTopProducts.sql
-- Schema: bi
-- Cross-schema: goldshop, store
-- Query. پرفروش‌ترین اقلام (§28/§96): طلا (فاکتورها) + محصولات فروشگاه (سفارش‌ها).
-- خروجی: جدول (Col1=کد, Col2=عنوان, Col3=تعداد, Col4=میانگین, Amount=فروش, SecondaryAmount=سود)
-- =============================================
SELECT TOP (@TakeSize) * FROM (
    SELECT g.ItemCode AS RowKey, g.ItemCode AS Col1,
           ISNULL(gi.Title, g.ItemCode) AS Col2,
           FORMAT(COUNT(*), 'N0') AS Col3,
           FORMAT(ROUND(AVG(g.TotalAmount), 0), 'N0') AS Col4,
           CAST(SUM(g.TotalAmount) AS DECIMAL(18,2)) AS Amount,
           CAST(SUM(ISNULL(g.Workmanship, 0) + ISNULL(g.Profit, 0)) AS DECIMAL(18,2)) AS SecondaryAmount,
           MAX(g.InvoiceDate) AS Date1,
           N'/goldshop/reports' AS Link
    FROM [goldshop].[SaleInvoices] g
    LEFT JOIN [goldshop].[GoldItems] gi ON gi.ItemCode = g.ItemCode
    GROUP BY g.ItemCode, gi.Title
    UNION ALL
    SELECT oi.ProductTitle AS RowKey, oi.ProductTitle,
           oi.ProductTitle,
           FORMAT(SUM(oi.Qty), 'N0'),
           FORMAT(ROUND(AVG(oi.UnitPrice * oi.Qty), 0), 'N0'),
           CAST(SUM(oi.UnitPrice * oi.Qty) AS DECIMAL(18,2)),
           CAST(SUM(oi.UnitPrice * oi.Qty) * 0.10 AS DECIMAL(18,2)),   -- پروکسی سود ۱۰٪ (فروشگاه)
           MAX(o.OrderDate),
           N'/store/reports'
    FROM [store].[OrderItems] oi
    JOIN [store].[Orders] o ON o.OrderId = oi.OrderId
    WHERE o.Status = N'Invoiced'
    GROUP BY oi.ProductTitle
) t
ORDER BY t.Amount DESC;
