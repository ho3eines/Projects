-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentStatusChange.sql
-- Schema: accounting
-- Execute. تغییر وضعیت سند حسابداری.
--
-- چرخهٔ وضعیت (مقادیر ذخیره‌شده همان مقادیر تاریخی پروژه‌اند تا گزارش‌های
-- موجود — BI با 'Posted' و بستن دوره با 'Closed' — نشکنند):
--   Note (یادداشت) → Draft (سند موقت) → Posted (تأیید شده) → Closed (تأیید نهایی)
-- برگشت وضعیت نیز فقط یک گام به عقب مجاز است.
--
-- @ExpectedStatus: وضعیتی که UI دیده است (کنترل هم‌زمانی). اگر سند در این فاصله
-- توسط کاربر دیگری تغییر کرده باشد، عملیات رد می‌شود.
-- =============================================
DECLARE @CurrentStatus NVARCHAR(50);
DECLARE @RawStatus     NVARCHAR(50);   -- مقدار خامِ ستون (ممکن است قدیمی/ناشناخته باشد)
DECLARE @Target NVARCHAR(50) = LTRIM(RTRIM(ISNULL(@NewStatus, N'')));

IF @Target NOT IN (N'Note', N'Draft', N'Posted', N'Closed')
    THROW 51048, N'وضعیت درخواستی معتبر نیست.', 1;

SELECT @RawStatus = d.Status
FROM [accounting].[Documents] d
WHERE d.DocumentId = @DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId;

IF @RawStatus IS NULL
    THROW 51045, N'سند پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت و سال مالی نیست', 1;

-- تغییر وضعیت سند در سال بسته ممنوع است (مگر برای بازگشایی که منطق جدا دارد).
IF EXISTS (SELECT 1 FROM [central].[FiscalYears]
           WHERE FiscalYearId = @FiscalYearId AND CompanyId = @CompanyId
             AND ISNULL([Status], N'Open') = N'Closed')
    THROW 51006, N'سال مالی بسته شده است؛ امکان تغییر وضعیت سند وجود ندارد.', 1;

-- مقادیر ناشناختهٔ قدیمی مثل وضعیت «سند موقت» رفتار می‌کنند (هم‌راستا با
-- AccountingDocumentStatus.Normalize در لایهٔ مشترک).
SET @CurrentStatus = CASE WHEN @RawStatus IN (N'Note', N'Draft', N'Posted', N'Closed')
                          THEN @RawStatus ELSE N'Draft' END;

IF @ExpectedStatus IS NOT NULL AND LTRIM(RTRIM(@ExpectedStatus)) <> N''
   AND @CurrentStatus <> LTRIM(RTRIM(@ExpectedStatus))
    THROW 51049, N'وضعیت سند توسط کاربر دیگری تغییر کرده است؛ صفحه را تازه‌سازی کنید.', 1;

IF @CurrentStatus = @Target
    RETURN;

-- فقط یک گام جلو یا یک گام عقب در چرخه.
DECLARE @CurIdx INT = CASE @CurrentStatus
                          WHEN N'Note' THEN 0 WHEN N'Draft' THEN 1
                          WHEN N'Posted' THEN 2 ELSE 3 END;
DECLARE @NewIdx INT = CASE @Target
                          WHEN N'Note' THEN 0 WHEN N'Draft' THEN 1
                          WHEN N'Posted' THEN 2 ELSE 3 END;

IF ABS(@NewIdx - @CurIdx) <> 1
    THROW 51050, N'تغییر وضعیت فقط یک گام (جلو یا عقب) در چرخهٔ سند مجاز است.', 1;

-- سند باید متوازن باشد تا از «یادداشت/موقت» فراتر برود.
IF @NewIdx >= 2
BEGIN
    DECLARE @Debit DECIMAL(18,2), @Credit DECIMAL(18,2);
    SELECT @Debit  = ISNULL(SUM(l.Debit), 0),
           @Credit = ISNULL(SUM(l.Credit), 0)
    FROM [accounting].[DocumentLines] l
    WHERE l.DocumentId = @DocumentId;

    IF @Debit <> @Credit OR @Debit <= 0
        THROW 51041, N'بدهی و بستانکاری سند برابر نیست', 1;
END

UPDATE [accounting].[Documents]
SET Status    = @Target,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy
WHERE DocumentId = @DocumentId AND IsDeleted = 0 AND Status = @RawStatus AND CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId;

IF @@ROWCOUNT = 0
    THROW 51049, N'وضعیت سند توسط کاربر دیگری تغییر کرده است؛ صفحه را تازه‌سازی کنید.', 1;
