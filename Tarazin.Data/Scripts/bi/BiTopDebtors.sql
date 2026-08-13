-- =============================================
-- Tarazin.Data/Scripts/bi/BiTopDebtors.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. Top Debtors (§18): بدهکاران بزرگ بر اساس اسناد فروش معوق (دادهٔ واقعی دفتر کل).
-- خروجی: جدول (Col1=طرف حساب, Col2=تعداد سند, Col3=آخرین سند, Col4=تأخیر, Amount=مانده)
-- =============================================
SELECT TOP (@TakeSize) d.CounterPartyName AS RowKey,
       d.CounterPartyName AS Col1,
       COUNT(*) AS Col2,
       CONVERT(NVARCHAR(10), MAX(d.DocumentDate), 111) AS Col3,
       CAST(DATEDIFF(DAY, MAX(d.DocumentDate), CAST(SYSDATETIME() AS DATE)) AS NVARCHAR(20)) AS Col4,
       CAST(SUM(d.TotalAmount) AS DECIMAL(18,2)) AS Amount,
       COUNT(*) AS SecondaryAmount,
       MAX(d.DocumentDate) AS Date1,
       N'/accounting' AS Link
FROM [accounting].[Documents] d
WHERE d.IsDeleted = 0
  AND d.DocumentType IN (N'Sale', N'FxSell', N'FxCombined')
  AND d.CounterPartyName IS NOT NULL
GROUP BY d.CounterPartyName
ORDER BY SUM(d.TotalAmount) DESC;
