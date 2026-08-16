-- =============================================
-- Tarazin.Data/Scripts/accounting/TrialBalanceReport.sql
-- Schema: accounting
-- Query. تراز آزمایشی از گردش واقعی؛ بدون JOIN چندبرابرکننده.
-- ChartOfAccounts فقط برای ماهیت حساب قدیمی و با تطابق دقیق کد خوانده می‌شود.
-- =============================================
;WITH Turnover AS (
    SELECT
        l.AccountCode,
        MAX(l.Title) AS AccountTitle,
        SUM(l.Debit) AS Debit,
        SUM(l.Credit) AS Credit
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
        AND d.IsDeleted = 0
        AND d.DocumentDate BETWEEN @FromDate AND @ToDate
    GROUP BY l.AccountCode
)
SELECT
    t.AccountCode,
    t.AccountTitle,
    a.AccountType,
    t.Debit,
    t.Credit,
    t.Debit - t.Credit AS Balance
FROM Turnover t
LEFT JOIN [accounting].[ChartOfAccounts] a ON a.AccountCode = t.AccountCode AND a.IsDeleted = 0
ORDER BY t.AccountCode;
