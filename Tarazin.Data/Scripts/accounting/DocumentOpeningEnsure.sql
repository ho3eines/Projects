-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentOpeningEnsure.sql
-- Schema: accounting
-- Execute (system-only).
--
-- تضمین وجود «سند ابتدای دوره / افتتاحیه» برای یک (CompanyId + FiscalYearId).
--
-- قوانین:
--   * برای هر (شرکت + سال مالی) فقط یک سند افتتاحیه وجود دارد.
--   * شماره سند افتتاحیه همیشه 00000001 است.
--   * اگر سند افتتاحیه از قبل وجود داشته باشد، همان برگردانده می‌شود
--     (جلوگیری از تکرار، حتی در Race Condition به‌کمک ایندکس یکتا).
--   * اگر اسناد دیگری قبلاً ثبت شده باشند و افتتاحیه هنوز وجود نداشته باشد،
--     باز هم افتتاحیه با شمارهٔ 00000001 ساخته می‌شود (سیستم، نه کاربر).
--     منطق شماره‌گذاری سایر اسناد در DocumentInsert به‌گونه‌ای است که
--     شمارهٔ 1 را برای افتتاحیه رزرو می‌کند.
--
-- خروجی: تک ردیف سند افتتاحیه.
-- پارامترها:
--   @CompanyId, @FiscalYearId, @CreatedBy
-- =============================================
SET NOCOUNT ON;

IF @CompanyId IS NULL OR @CompanyId <= 0
    THROW 51120, N'شناسه شرکت مالی نامعتبر است.', 1;
IF @FiscalYearId IS NULL OR @FiscalYearId <= 0
    THROW 51121, N'شناسه سال مالی نامعتبر است.', 1;

DECLARE @FyStart DATE, @FyEnd DATE, @FyStatus NVARCHAR(20);
SELECT @FyStart = fy.StartDate,
       @FyEnd   = fy.EndDate,
       @FyStatus = ISNULL(fy.[Status], N'Open')
FROM [central].[FiscalYears] fy
WHERE fy.FiscalYearId = @FiscalYearId AND fy.CompanyId = @CompanyId AND fy.IsDeleted = 0;

IF @FyStart IS NULL
    THROW 51122, N'سال مالی برای این شرکت یافت نشد.', 1;

IF @FyStatus = N'Closed'
    THROW 51123, N'سال مالی بسته شده است؛ ایجاد یا تغییر سند افتتاحیه مجاز نیست.', 1;

DECLARE @OpeningId INT;

SELECT @OpeningId = d.DocumentId
FROM [accounting].[Documents] d
WHERE d.CompanyId = @CompanyId
  AND d.FiscalYearId = @FiscalYearId
  AND d.DocumentType = N'Opening'
  AND d.IsDeleted = 0;

IF @OpeningId IS NULL
BEGIN
    -- اگر سندی با شماره 00000001 وجود دارد که افتتاحیه نیست، فقط در شرایط
    -- نادری رخ می‌دهد که منطق قدیمی شماره‌ها را اشتباه تخصیص داده باشد.
    -- برای جلوگیری از شکست درج، همهٔ شماره‌های ۸ رقمی موجود را یک واحد
    -- به جلو شیفت می‌کنیم (از انتها به ابتدا برای جلوگیری از نقض یکتایی).
    IF EXISTS (
        SELECT 1 FROM [accounting].[Documents]
        WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId
          AND DocumentNumber = N'00000001' AND ISNULL(DocumentType, N'') <> N'Opening' AND IsDeleted = 0)
    BEGIN
        DECLARE @sql NVARCHAR(MAX) = N'
            ;WITH Ordered AS (
                SELECT DocumentId,
                       ROW_NUMBER() OVER (ORDER BY TRY_CONVERT(INT, DocumentNumber) DESC, DocumentId DESC) + 1 AS NewNum
                FROM [accounting].[Documents]
                WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId
                  AND TRY_CONVERT(INT, DocumentNumber) IS NOT NULL
                  AND IsDeleted = 0
            )
            UPDATE o SET o.DocumentNumber = RIGHT(''00000000'' + CAST(src.NewNum AS NVARCHAR(10)), 8)
            FROM [accounting].[Documents] o INNER JOIN Ordered src ON src.DocumentId = o.DocumentId;';
        EXEC sp_executesql @sql, N'@CompanyId INT, @FiscalYearId INT', @CompanyId, @FiscalYearId;
    END

    BEGIN TRY
        INSERT INTO [accounting].[Documents]
            (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount,
             CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
        VALUES
            (N'00000001', @FyStart, N'Opening', NULL, 0, N'IRR', N'Draft',
             SYSUTCDATETIME(), @CreatedBy, 0, @CompanyId, @FiscalYearId);

        SET @OpeningId = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
        BEGIN
            SELECT @OpeningId = d.DocumentId
            FROM [accounting].[Documents] d
            WHERE d.CompanyId = @CompanyId
              AND d.FiscalYearId = @FiscalYearId
              AND d.DocumentType = N'Opening'
              AND d.IsDeleted = 0;
        END
        ELSE
            THROW;
    END CATCH
END

-- برگرداندن سند افتتاحیه.
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
WHERE d.DocumentId = @OpeningId;
