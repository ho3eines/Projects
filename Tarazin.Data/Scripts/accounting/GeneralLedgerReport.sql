-- =============================================
-- Tarazin.Data/Scripts/accounting/GeneralLedgerReport.sql
-- Schema: accounting
-- دفتر کل بر اساس کد واقعی ذخیره‌شده روی ردیف سند.
-- اتصال تاریخ و فیلتر سند در INNER JOIN انجام می‌شود تا گردش نامرتبط وارد SUM نشود.
-- =============================================
DECLARE @Status NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@StatusFilter)), N'');
DECLARE @Number NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@DocumentNumber)), N'');

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
    AND d.CompanyId = @CompanyId
    AND d.FiscalYearId = @FiscalYearId
    AND d.DocumentDate BETWEEN @FromDate AND @ToDate
    AND (@Status IS NULL OR d.Status = @Status)
    AND (@Number IS NULL OR d.DocumentNumber LIKE N'%' + @Number + N'%')
WHERE @AccountId IS NULL OR l.AccountId = @AccountId
GROUP BY l.AccountCode
HAVING SUM(l.Debit) <> 0 OR SUM(l.Credit) <> 0
ORDER BY l.AccountCode;
