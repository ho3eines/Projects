-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentNeighbors.sql
-- Schema: accounting
-- برادرهای قبلی/بعدی یک سند (برای دکمه‌های «سند قبل/بعد» در صفحهٔ سند).
-- ترتیب مطابق فهرست «اسناد روز»: تاریخ و شماره نزولی.
-- محدود به شرکت و سال مالی فعال؛ نمونهٔ حذف‌شده لحاظ نمی‌شود.
-- 'قبل' = سندِ قدیمی‌تر در تاریخ/شماره، 'بعد' = جدیدتر.
-- خروجی: یک ردیف؛ در نبود همسایه مقدار 0 / NULL برمی‌گردد.
-- =============================================
SELECT
    ISNULL((
        SELECT TOP (1) d.DocumentId
        FROM [accounting].[Documents] d
        WHERE d.CompanyId = @CompanyId
          AND d.FiscalYearId = @FiscalYearId
          AND d.IsDeleted = 0
          AND (d.DocumentDate < CONVERT(DATE, @CurrentDate)
               OR (d.DocumentDate = CONVERT(DATE, @CurrentDate) AND d.DocumentNumber < @CurrentNumber))
        ORDER BY d.DocumentDate DESC, d.DocumentNumber DESC
    ), 0) AS PrevDocumentId,

    (SELECT TOP (1) d.DocumentNumber
     FROM [accounting].[Documents] d
     WHERE d.CompanyId = @CompanyId
       AND d.FiscalYearId = @FiscalYearId
       AND d.IsDeleted = 0
       AND (d.DocumentDate < CONVERT(DATE, @CurrentDate)
            OR (d.DocumentDate = CONVERT(DATE, @CurrentDate) AND d.DocumentNumber < @CurrentNumber))
     ORDER BY d.DocumentDate DESC, d.DocumentNumber DESC) AS PrevNumber,

    ISNULL((
        SELECT TOP (1) d.DocumentId
        FROM [accounting].[Documents] d
        WHERE d.CompanyId = @CompanyId
          AND d.FiscalYearId = @FiscalYearId
          AND d.IsDeleted = 0
          AND (d.DocumentDate > CONVERT(DATE, @CurrentDate)
               OR (d.DocumentDate = CONVERT(DATE, @CurrentDate) AND d.DocumentNumber > @CurrentNumber))
        ORDER BY d.DocumentDate ASC, d.DocumentNumber ASC
    ), 0) AS NextDocumentId,

    (SELECT TOP (1) d.DocumentNumber
     FROM [accounting].[Documents] d
     WHERE d.CompanyId = @CompanyId
       AND d.FiscalYearId = @FiscalYearId
       AND d.IsDeleted = 0
       AND (d.DocumentDate > CONVERT(DATE, @CurrentDate)
            OR (d.DocumentDate = CONVERT(DATE, @CurrentDate) AND d.DocumentNumber > @CurrentNumber))
     ORDER BY d.DocumentDate ASC, d.DocumentNumber ASC) AS NextNumber;