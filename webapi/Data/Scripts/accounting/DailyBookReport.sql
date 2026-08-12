-- =============================================
-- webapi/Data/Scripts/accounting/DailyBookReport.sql
-- Schema: accounting
-- Query. دفتر روزنامه — ردیف‌های سند در بازهٔ تاریخ.
-- =============================================
SELECT
    l.DocumentId,
    d.DocumentDate,
    d.DocumentNumber,
    d.DocumentType,
    d.CounterPartyName,
    l.AccountCode,
    l.Title        AS AccountTitle,
    l.Description,
    l.Debit,
    l.Credit
FROM [accounting].[DocumentLines] l
JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
WHERE d.DocumentDate BETWEEN @FromDate AND @ToDate
  AND d.IsDeleted = 0
ORDER BY d.DocumentDate, d.DocumentNumber, l.DocumentLineId;
