-- =============================================
-- Tarazin.Data/Scripts/accounting/GeneralLedgerReport.sql
-- Schema: accounting
-- Query. دفتر کل بر اساس کد واقعی ذخیره‌شده روی ردیف سند.
-- اتصال تاریخ در WHERE/INNER JOIN انجام می‌شود تا گردش خارج بازه وارد SUM نشود.
-- =============================================
SELECT
    MIN(l.AccountId) AS AccountId,
    l.AccountCode,
    MAX(l.Title) AS AccountTitle,
    SUM(l.Debit) AS Debit,
    SUM(l.Credit) AS Credit,
    SUM(l.Debit - l.Credit) AS Balance
FROM [accounting].[DocumentLines] l
INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    AND d.IsDeleted = 0
    AND d.DocumentDate BETWEEN @FromDate AND @ToDate
WHERE @AccountId IS NULL OR l.AccountId = @AccountId
GROUP BY l.AccountCode
HAVING SUM(l.Debit) <> 0 OR SUM(l.Credit) <> 0
ORDER BY l.AccountCode;
