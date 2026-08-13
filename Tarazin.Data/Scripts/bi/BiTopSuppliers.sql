-- =============================================
-- Tarazin.Data/Scripts/bi/BiTopSuppliers.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. Top Suppliers (§23): تأمین‌کنندگان برتر از اسناد خرید.
-- خروجی: جدول (Col1=نام, Col2=تعداد سند, Col3=آخرین خرید, Col4=میانگین, Amount=مجموع)
-- =============================================
SELECT TOP (@TakeSize) d.CounterPartyName AS RowKey,
       d.CounterPartyName AS Col1,
       COUNT(*) AS Col2,
       CONVERT(NVARCHAR(10), MAX(d.DocumentDate), 111) AS Col3,
       FORMAT(ROUND(AVG(d.TotalAmount), 0), 'N0') AS Col4,
       CAST(SUM(d.TotalAmount) AS DECIMAL(18,2)) AS Amount,
       COUNT(*) AS SecondaryAmount,
       MAX(d.DocumentDate) AS Date1,
       N'/accounting' AS Link
FROM [accounting].[Documents] d
WHERE d.IsDeleted = 0 AND d.DocumentType = N'Purchase' AND d.CounterPartyName IS NOT NULL
GROUP BY d.CounterPartyName
ORDER BY SUM(d.TotalAmount) DESC;
