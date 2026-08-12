-- =============================================
-- Tarazin.Data/Scripts/accounting/GeneralLedgerReport.sql
-- Schema: accounting
-- Query. دفتر کل — جمع بدهکار/بستانکار و ماندهٔ هر حساب در بازه.
-- @AccountId (optional) filters to one account.
-- =============================================
SELECT
    a.AccountId,
    a.AccountCode,
    a.Title                          AS AccountTitle,
    ISNULL(SUM(l.Debit), 0)          AS Debit,
    ISNULL(SUM(l.Credit), 0)         AS Credit,
    ISNULL(SUM(l.Debit), 0) - ISNULL(SUM(l.Credit), 0) AS Balance
FROM [accounting].[ChartOfAccounts] a
LEFT JOIN [accounting].[DocumentLines] l ON l.AccountId = a.AccountId
LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
      AND d.DocumentDate BETWEEN @FromDate AND @ToDate AND d.IsDeleted = 0
WHERE a.IsDeleted = 0
  AND (@AccountId IS NULL OR a.AccountId = @AccountId)
GROUP BY a.AccountId, a.AccountCode, a.Title
HAVING ISNULL(SUM(l.Debit), 0) <> 0 OR ISNULL(SUM(l.Credit), 0) <> 0
ORDER BY a.AccountCode;
