-- =============================================
-- webapi/Data/Scripts/accounting/TrialBalanceReport.sql
-- Schema: accounting
-- Query. تراز آزمایشی — ماندهٔ همهٔ حساب‌ها در بازهٔ تاریخ.
-- =============================================
SELECT
    a.AccountCode,
    a.Title        AS AccountTitle,
    a.AccountType,
    ISNULL(SUM(l.Debit), 0)          AS Debit,
    ISNULL(SUM(l.Credit), 0)         AS Credit,
    ISNULL(SUM(l.Debit), 0) - ISNULL(SUM(l.Credit), 0) AS Balance
FROM [accounting].[ChartOfAccounts] a
LEFT JOIN [accounting].[DocumentLines] l ON l.AccountId = a.AccountId
LEFT JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
      AND d.DocumentDate BETWEEN @FromDate AND @ToDate AND d.IsDeleted = 0
WHERE a.IsDeleted = 0
GROUP BY a.AccountCode, a.Title, a.AccountType
ORDER BY a.AccountCode;
