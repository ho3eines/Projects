-- =============================================
-- Tarazin.Data/Scripts/accounting/DailyBookReport.sql
-- Schema: accounting
-- دفتر روزنامه — ردیف‌های واقعی سند در بازه و فیلتر انتخاب‌شده.
-- =============================================
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

SELECT
    l.DocumentLineId,
    l.DocumentId,
    d.DocumentDate,
    d.DocumentNumber,
    d.DocumentType,
    d.CounterPartyName,
    l.AccountCode,
    l.Title AS AccountTitle,
    l.Description,
    l.Debit,
    l.Credit,
    d.Status,
    SUM(l.Debit - l.Credit) OVER (
        PARTITION BY l.AccountCode
        ORDER BY d.DocumentDate, d.DocumentId, l.DocumentLineId
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Balance
FROM [accounting].[DocumentLines] l
INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
WHERE d.DocumentDate BETWEEN @FromDate AND @ToDate
  AND d.IsDeleted = 0
  AND (@Status IS NULL OR d.Status = @Status)
  AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
ORDER BY d.DocumentDate, d.DocumentId, l.DocumentLineId;
