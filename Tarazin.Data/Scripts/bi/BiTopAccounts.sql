-- =============================================
-- Tarazin.Data/Scripts/bi/BiTopAccounts.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. تحلیل دفتر کل (§92): پرگردش‌ترین حساب‌ها در بازه.
-- خروجی: جدول (Col1=کد, Col2=عنوان, Col3=بدهکار, Col4=بستانکار, Amount=گردش کل)
-- =============================================
SELECT TOP (@TakeSize) a.AccountCode AS RowKey,
       a.AccountCode AS Col1,
       a.Title AS Col2,
       FORMAT(ISNULL(SUM(l.Debit), 0), 'N0') AS Col3,
       FORMAT(ISNULL(SUM(l.Credit), 0), 'N0') AS Col4,
       CAST(ISNULL(SUM(l.Debit), 0) + ISNULL(SUM(l.Credit), 0) AS DECIMAL(18,2)) AS Amount,
       CAST(ISNULL(SUM(l.Debit), 0) - ISNULL(SUM(l.Credit), 0) AS DECIMAL(18,2)) AS SecondaryAmount,
       MAX(d.DocumentDate) AS Date1,
       N'/accounting/reports' AS Link
FROM [accounting].[DocumentLines] l
JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
WHERE d.Status = N'Posted' AND d.IsDeleted = 0
  AND (@FromDate IS NULL OR d.DocumentDate >= @FromDate)
  AND (@ToDate IS NULL OR d.DocumentDate <= @ToDate)
GROUP BY a.AccountCode, a.Title
ORDER BY (ISNULL(SUM(l.Debit), 0) + ISNULL(SUM(l.Credit), 0)) DESC;
