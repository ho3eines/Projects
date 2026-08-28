-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentClosingGenerate.sql
-- Schema: accounting
-- Cross-schema: central
-- Execute (system-only, with permission check by caller).
--
-- بستن سال مالی:
--   ۱. بررسی می‌کند سال مالی برای این شرکت پیدا شود و بسته نشده باشد.
--   ۲. بررسی می‌کند تمام اسناد سال به‌جز افتتاحیه/اختتامیه حداقل در
--      وضعیت «تأیید شده» (Posted) یا «تأیید نهایی» (Closed) باشند.
--      سند در یادداشت/موقت مانع بستن سال است.
--   ۳. ماندهٔ خالص هر حساب (بدهکار - بستانکار) را از روی تمام اسناد
--      غیر اختتامیه محاسبه می‌کند.
--   ۴. سند اختتامیه را می‌سازد یا به‌روز می‌کند:
--        * اگر سند اختتامیه وجود ندارد → ایجاد با آخرین شماره سال.
--        * اگر وجود دارد → حذف منطقی ردیف‌ها و درج ردیف‌های جدید
--          (به‌روزرسانی خودکار، نه ایجاد سند تکراری).
--   ۵. وضعیت سال مالی را به Closed تغییر می‌دهد.
--   ۶. تمام اسناد سال را به وضعیت «تأیید نهایی» (Closed) می‌برد.
--
-- خروجی: تک ردیف سند اختتامیه.
-- پارامترها:
--   @CompanyId, @FiscalYearId, @CreatedBy
-- =============================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @CompanyId IS NULL OR @CompanyId <= 0
    THROW 51130, N'شناسه شرکت مالی نامعتبر است.', 1;
IF @FiscalYearId IS NULL OR @FiscalYearId <= 0
    THROW 51131, N'شناسه سال مالی نامعتبر است.', 1;

DECLARE @FyStart DATE, @FyEnd DATE, @FyStatus NVARCHAR(20);
SELECT @FyStart = fy.StartDate,
       @FyEnd   = fy.EndDate,
       @FyStatus = ISNULL(fy.[Status], N'Open')
FROM [central].[FiscalYears] fy
WHERE fy.FiscalYearId = @FiscalYearId AND fy.CompanyId = @CompanyId AND fy.IsDeleted = 0;

IF @FyStart IS NULL
    THROW 51132, N'سال مالی برای این شرکت یافت نشد.', 1;

IF @FyStatus = N'Closed'
    THROW 51133, N'سال مالی قبلاً بسته شده است.', 1;

-- هیچ سند یادداشت/موقتی نباید در زمان بستن سال باقی بماند.
IF EXISTS (
    SELECT 1 FROM [accounting].[Documents]
    WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0
      AND [Status] IN (N'Note', N'Draft')
      AND ISNULL(DocumentType, N'') <> N'Opening'
)
    THROW 51134, N'اسناد در وضعیت یادداشت/موقت مانع بستن سال هستند. ابتدا آن‌ها را تأیید یا حذف کنید.', 1;

DECLARE @ClosingId INT;
SELECT @ClosingId = d.DocumentId
FROM [accounting].[Documents] d
WHERE d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
  AND d.DocumentType = N'Closing' AND d.IsDeleted = 0;

-- محاسبهٔ مانده‌ها: همهٔ اسناد حذف‌نشده به‌جز اختتامیه.
-- برای هر حساب با ماندهٔ خالص غیر صفر، ردیف معکوس ساخته می‌شود.
IF OBJECT_ID('tempdb..#ClosingLines') IS NOT NULL DROP TABLE #ClosingLines;

CREATE TABLE #ClosingLines (
    AccountId    INT NOT NULL,
    AccountCode  NVARCHAR(30) NOT NULL,
    Title        NVARCHAR(200) NOT NULL,
    Debit        DECIMAL(18,2) NOT NULL DEFAULT 0,
    Credit       DECIMAL(18,2) NOT NULL DEFAULT 0
);

;WITH Balances AS (
    SELECT
        l.AccountId,
        l.AccountCode,
        MAX(l.Title) AS Title,
        ISNULL(SUM(l.Debit), 0)  AS TotalDebit,
        ISNULL(SUM(l.Credit), 0) AS TotalCredit
    FROM [accounting].[DocumentLines] l
    INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    WHERE d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
      AND d.IsDeleted = 0
      AND ISNULL(d.DocumentType, N'') <> N'Closing'
    GROUP BY l.AccountId, l.AccountCode
    HAVING ISNULL(SUM(l.Debit), 0) <> ISNULL(SUM(l.Credit), 0)
)
INSERT INTO #ClosingLines (AccountId, AccountCode, Title, Debit, Credit)
SELECT
    AccountId,
    AccountCode,
    Title,
    -- معکوس مانده: اگر مانده خالص بستانکار است (بستانکار > بدهکار)، ردیف معکوس
    -- باید بدهکار شود (بستن سمت بستانکار)؛ و اگر مانده خالص بدهکار است، بستانکار شود.
    CASE WHEN TotalCredit > TotalDebit THEN TotalCredit - TotalDebit ELSE 0 END AS Debit,
    CASE WHEN TotalDebit > TotalCredit THEN TotalDebit - TotalCredit ELSE 0 END AS Credit
FROM Balances;

-- اگر هیچ ردیفی نبود (سال کاملاً توازن دارد / فعالیتی نبوده) سند اختتامیه
-- بدون ردیف با مجموع صفر — ولی برای رعایت قاعدهٔ «سند با ردیف»، یک ردیف
-- خنثی نمی‌سازیم. سند اختتامیه می‌تواند بدون ردیف باشد (وضعیت یادداشت/موقت).
-- ولی برای جلوگیری از شکست قواعد موجود، اگر هیچ ردیفی نبود، سال را
-- بدون ایجاد سند اختتامیه هم می‌بندیم.
DECLARE @HasLines BIT = CASE WHEN EXISTS (SELECT 1 FROM #ClosingLines) THEN 1 ELSE 0 END;
DECLARE @Total DECIMAL(18,2) = (SELECT ISNULL(SUM(Debit), 0) FROM #ClosingLines);

BEGIN TRAN;

    IF @HasLines = 1
    BEGIN
        IF @ClosingId IS NULL
        BEGIN
            -- تعیین آخرین شماره سال (شماره‌ها دقیقاً ۸ رقمی‌اند).
            DECLARE @NextNum INT;
            SELECT @NextNum = ISNULL(MAX(TRY_CONVERT(INT, DocumentNumber)), 0) + 1
            FROM [accounting].[Documents]
            WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0;

            DECLARE @DocNum NVARCHAR(50) = RIGHT('00000000' + CAST(@NextNum AS NVARCHAR(10)), 8);

            INSERT INTO [accounting].[Documents]
                (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount,
                 CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
            VALUES
                (@DocNum, @FyEnd, N'Closing', N'سند اختتامیه سیستم', @Total, N'IRR', N'Closed',
                 SYSUTCDATETIME(), @CreatedBy, 0, @CompanyId, @FiscalYearId);

            SET @ClosingId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- به‌روزرسانی سند اختتامیهٔ موجود (حذف ردیف‌های قبلی و درج جدید).
            DELETE FROM [accounting].[DocumentLines] WHERE DocumentId = @ClosingId;

            DECLARE @MaxNum INT;
            SELECT @MaxNum = ISNULL(MAX(TRY_CONVERT(INT, DocumentNumber)), 0)
            FROM [accounting].[Documents]
            WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId
              AND IsDeleted = 0 AND DocumentId <> @ClosingId;

            UPDATE [accounting].[Documents]
            SET DocumentDate = @FyEnd,
                TotalAmount  = @Total,
                [Status]     = N'Closed',
                UpdatedAt    = SYSUTCDATETIME(),
                UpdatedBy    = @CreatedBy,
                DocumentNumber = RIGHT('00000000' +
                    CAST(CASE WHEN TRY_CONVERT(INT, DocumentNumber) > @MaxNum
                              THEN TRY_CONVERT(INT, DocumentNumber)
                              ELSE @MaxNum + 1 END AS NVARCHAR(10)), 8)
            WHERE DocumentId = @ClosingId;
        END

        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @ClosingId, AccountId, AccountCode, Title, N'سند اختتامیه - بستن مانده حساب', Debit, Credit
        FROM #ClosingLines;
    END

    -- بستن وضعیت تمام اسناد سال که هنوز تأیید نشده‌اند (Posted → Closed).
    UPDATE [accounting].[Documents]
    SET [Status] = N'Closed', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
    WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId
      AND IsDeleted = 0
      AND [Status] <> N'Closed';

    -- به‌روزرسانی وضعیت سال مالی به بسته.
    UPDATE [central].[FiscalYears]
    SET [Status]  = N'Closed',
        IsActive  = 1,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE FiscalYearId = @FiscalYearId AND CompanyId = @CompanyId;

    -- ════════════════════════════════════════════════════════════════
    -- انتقال خودکار مانده‌ها به سال مالی بعد (سند افتتاحیهٔ سال جدید)
    -- ════════════════════════════════════════════════════════════════
    -- سال بعد = اولین سال مالیِ همان شرکت با تاریخ شروع بزرگ‌تر از پایان سال جاری.
    -- اگر سال بعد وجود داشته باشد، سند افتتاحیهٔ آن با مانده‌های طبیعی حساب‌ها
    -- (برعکس سند اختتامیه) ساخته/به‌روز می‌شود تا سال جدید با ماندهٔ واقعی شروع شود.
    DECLARE @NextFiscalYearId INT = (
        SELECT TOP 1 fy.FiscalYearId
        FROM [central].[FiscalYears] fy
        WHERE fy.CompanyId = @CompanyId AND fy.IsDeleted = 0
          AND fy.StartDate > @FyEnd
        ORDER BY fy.StartDate);

    IF @NextFiscalYearId IS NOT NULL AND EXISTS (SELECT 1 FROM #ClosingLines)
    BEGIN
        DECLARE @NextFyStart DATE = (SELECT StartDate FROM [central].[FiscalYears] WHERE FiscalYearId = @NextFiscalYearId);
        DECLARE @NextOpeningId INT = (
            SELECT TOP 1 d.DocumentId FROM [accounting].[Documents] d
            WHERE d.CompanyId = @CompanyId AND d.FiscalYearId = @NextFiscalYearId
              AND d.DocumentType = N'Opening' AND d.IsDeleted = 0);

        IF @NextOpeningId IS NULL
        BEGIN
            -- آزادسازی شمارهٔ 1 برای سند افتتاحیه (مثل DocumentOpeningEnsure)
            IF EXISTS (SELECT 1 FROM [accounting].[Documents]
                       WHERE CompanyId = @CompanyId AND FiscalYearId = @NextFiscalYearId
                         AND DocumentNumber = N'00000001' AND ISNULL(DocumentType, N'') <> N'Opening' AND IsDeleted = 0)
            BEGIN
                DECLARE @ShiftSql NVARCHAR(MAX) = N'
                    UPDATE [accounting].[Documents]
                    SET DocumentNumber = CAST(TRY_CONVERT(INT, DocumentNumber) - 1000000 AS NVARCHAR(20))
                    WHERE CompanyId = @CompanyId AND FiscalYearId = @NextFiscalYearId
                      AND TRY_CONVERT(INT, DocumentNumber) IS NOT NULL AND IsDeleted = 0;
                    UPDATE [accounting].[Documents]
                    SET DocumentNumber = RIGHT(''00000000'' + CAST(TRY_CONVERT(INT, DocumentNumber) + 1000001 AS NVARCHAR(10)), 8)
                    WHERE CompanyId = @CompanyId AND FiscalYearId = @NextFiscalYearId
                      AND TRY_CONVERT(INT, DocumentNumber) < 0 AND IsDeleted = 0;';
                EXEC sp_executesql @ShiftSql, N'@CompanyId INT, @NextFiscalYearId INT', @CompanyId, @NextFiscalYearId;
            END
            INSERT INTO [accounting].[Documents]
                (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount,
                 CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
            VALUES
                (N'00000001', @NextFyStart, N'Opening', N'سند افتتاحیه سیستم', 0, N'IRR', N'Draft',
                 SYSUTCDATETIME(), @CreatedBy, 0, @CompanyId, @NextFiscalYearId);
            SET @NextOpeningId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- به‌روزرسانی سند افتتاحیهٔ موجود: ردیف‌های قبلی پاک و با ماندهٔ جدید پر می‌شود.
            DELETE FROM [accounting].[DocumentLines] WHERE DocumentId = @NextOpeningId;
            UPDATE [accounting].[Documents]
            SET DocumentDate = @NextFyStart, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
            WHERE DocumentId = @NextOpeningId;
        END

        -- ردیف‌های افتتاحیه = برعکس اختتامیه (ماندهٔ طبیعی حساب: بدهکار → بدهکار).
        DECLARE @OpeningTotal DECIMAL(18,2) = (SELECT ISNULL(SUM(Credit), 0) FROM #ClosingLines);
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @NextOpeningId, AccountId, AccountCode, Title, N'مانده انتقالی از سال مالی قبلی (سند افتتاحیه)', Credit, Debit
        FROM #ClosingLines;

        UPDATE [accounting].[Documents]
        SET TotalAmount = @OpeningTotal, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
        WHERE DocumentId = @NextOpeningId;
    END

COMMIT;

IF @ClosingId IS NOT NULL
BEGIN
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
    WHERE d.DocumentId = @ClosingId;
END
