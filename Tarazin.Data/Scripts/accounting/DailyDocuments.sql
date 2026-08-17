-- =============================================
-- Tarazin.Data/Scripts/accounting/DailyDocuments.sql
-- Schema: accounting
-- Returns today's documents for the main page grid
-- =============================================
SELECT
    d.DocumentId,
    d.DocumentNumber,
    d.DocumentDate,
    d.DocumentType,
    d.CounterPartyName,
    d.TotalAmount,
    d.CurrencyCode,
    d.Status,
    d.CreatedAt,
    d.UpdatedAt,
    d.CreatedBy,
    d.UpdatedBy
FROM [accounting].[Documents] d
-- ⚠ باگ تاریخی (رفع شد): فیلتر IsDeleted وجود نداشت، پس اسناد حذف‌شده
--   همچنان در فهرست «اسناد روز» دیده می‌شدند.
WHERE d.DocumentDate BETWEEN @FromDate AND @ToDate
  AND d.IsDeleted = 0
  AND d.CompanyId = @CompanyId
  AND d.FiscalYearId = @FiscalYearId
  AND (@SearchText = '' OR d.DocumentNumber LIKE '%' + @SearchText + '%'
       OR d.CounterPartyName LIKE '%' + @SearchText + '%')
  AND (@DocumentType IS NULL OR d.DocumentType = @DocumentType)
ORDER BY d.DocumentDate DESC, d.DocumentNumber DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;