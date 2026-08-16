-- =============================================
-- Tarazin.Data/Scripts/accounting/DetailAccountTransactions.sql
-- Schema: accounting
-- Query. گردش تفصیلی با ماندهٔ جاری و صفحه‌بندی سمت سرور.
-- ترتیب قطعی: تاریخ، شناسهٔ سند، شناسهٔ ردیف.
-- =============================================
DECLARE @From DATE = CAST(@FromDate AS DATE);
DECLARE @To DATE = CAST(@ToDate AS DATE);
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

;WITH Opening AS (
    SELECT ISNULL(SUM(l.Debit - l.Credit), 0) AS Amount
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId AND d.IsDeleted = 0
    WHERE l.AccountCode = @AccountCode AND d.DocumentDate < @From
      AND (@Status IS NULL OR d.Status = @Status)
      AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
),
Movement AS (
    SELECT
        l.DocumentLineId, l.DocumentId, d.DocumentDate, d.DocumentNumber,
        d.DocumentType, d.CounterPartyName AS DocumentDescription,
        l.Description AS LineDescription, l.AccountCode, l.Title AS AccountTitle,
        l.Debit, l.Credit, d.Status,
        COUNT_BIG(*) OVER() AS TotalRows,
        ROW_NUMBER() OVER (ORDER BY d.DocumentDate, d.DocumentId, l.DocumentLineId) AS RowNumber,
        SUM(l.Debit - l.Credit) OVER (
            ORDER BY d.DocumentDate, d.DocumentId, l.DocumentLineId
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS PeriodBalance
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId AND d.IsDeleted = 0
    WHERE l.AccountCode = @AccountCode AND d.DocumentDate BETWEEN @From AND @To
      AND (@Status IS NULL OR d.Status = @Status)
      AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
)
SELECT
    m.DocumentLineId, m.DocumentId, m.DocumentDate, m.DocumentNumber,
    m.DocumentType, m.DocumentDescription, m.LineDescription,
    m.AccountCode, m.AccountTitle, m.Debit, m.Credit, m.Status,
    o.Amount + m.PeriodBalance AS Balance,
    m.TotalRows
FROM Movement m
CROSS JOIN Opening o
WHERE m.RowNumber > @SkipRows AND m.RowNumber <= @SkipRows + @TakeSize
ORDER BY m.RowNumber;
