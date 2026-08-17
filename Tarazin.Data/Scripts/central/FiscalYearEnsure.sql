-- =============================================
-- Tarazin.Data/Scripts/central/FiscalYearEnsure.sql
-- Schema: central
-- Execute (system-only).
--
-- تضمین وجود سال مالی برای یک شرکت و نام سال (مثلاً ۱۴۰۵).
-- این تنها مسیر سیستمیِ «ایجاد سال مالی» است؛ کاربر هیچ راهی برای
-- ایجاد دستی سال مالی ندارد.
--
-- ویژگی‌ها:
--   * تاریخ شروع/پایان به‌صورت خودکار و بر اساس سال شمسی محاسبه می‌شود.
--     (محاسبه در لایهٔ C# با PersianCalendar انجام و به این اسکریپت پاس داده
--      می‌شود تا وابستگی به تقویم SQL Server نداشته باشیم.)
--   * در صورت وجود سال مالی قبلی برای (CompanyId, YearName)، همان رکورد
--     برگردانده می‌شود (idempotent).
--   * در صورت عدم وجود، رکورد جدید با وضعیت Open ایجاد می‌شود.
--   * جلوی ایجاد رکورد تکراری در شرایط هم‌زمان با یک ایندکس یکتا
--     (UX_FiscalYears_Company_Year) گرفته می‌شود؛ در صورت برخورد، اسکریپت
--     رکورد رقیب را برمی‌گرداند.
--   * به‌صورت پیش‌فرض به کاربر درخواست‌دهنده دسترسی سال مالی داده می‌شود.
--
-- خروجی: تک ردیف FiscalYearRow.
-- پارامترها:
--   @CompanyId   — شرکت مالی
--   @YearName    — نام سال شمسی (مثلاً N'1405')
--   @StartDate   — تاریخ شروع (معمولاً 1405/01/01)
--   @EndDate     — تاریخ پایان (1405/12/29 یا 1405/12/30 کبیسه)
--   @UserId      — کاربر درخواست‌دهنده (برای اعطای دسترسی)
--   @CreatedBy   — نام کاربر برای ثبت ممیزی
-- =============================================
SET NOCOUNT ON;

IF @CompanyId IS NULL OR @CompanyId <= 0
    THROW 51100, N'شناسه شرکت مالی نامعتبر است.', 1;

IF @YearName IS NULL OR LTRIM(RTRIM(@YearName)) = N''
    THROW 51101, N'نام سال مالی الزامی است.', 1;

IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate > @EndDate
    THROW 51102, N'تاریخ شروع/پایان سال مالی نامعتبر است.', 1;

-- اعتبار شرکت
IF NOT EXISTS (SELECT 1 FROM [central].[Companies] WHERE CompanyId = @CompanyId AND IsDeleted = 0 AND IsActive = 1)
    THROW 51103, N'شرکت مالی فعال یافت نشد.', 1;

DECLARE @FiscalYearId INT;

-- ۱) اگر قبلاً وجود دارد همان را برگردان.
SELECT @FiscalYearId = FiscalYearId
FROM [central].[FiscalYears]
WHERE CompanyId = @CompanyId AND YearName = @YearName AND IsDeleted = 0;

-- ۲) در غیر این صورت تلاش برای درج. اگر درخواست هم‌زمان رقیبی زودتر درج
--    کرده باشد، ایندکس یکتا خطا می‌دهد؛ خطا را می‌گیریم و رکورد رقیب را
--    برمی‌گردانیم.
IF @FiscalYearId IS NULL
BEGIN
    BEGIN TRY
        INSERT INTO [central].[FiscalYears]
            (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
        VALUES
            (@CompanyId, @YearName, @StartDate, @EndDate, 1, N'Open', SYSUTCDATETIME(), @CreatedBy);

        SET @FiscalYearId = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        -- خطای 2601/2627 = نقض یکتایی (رقیب هم‌زمان ثبت کرده).
        IF ERROR_NUMBER() IN (2601, 2627)
        BEGIN
            SELECT @FiscalYearId = FiscalYearId
            FROM [central].[FiscalYears]
            WHERE CompanyId = @CompanyId AND YearName = @YearName AND IsDeleted = 0;
        END
        ELSE
            THROW;
    END CATCH
END

-- ۳) اگر سال مالی از قبل وجود داشته ولی تاریخ‌ها/وضعیتش اشتباه باشد
--    (سناریوی ارتقای دیتابیس یا داده‌های قدیمی)، آن را تصحیح کن
--    مگر این‌که سال بسته شده باشد (دست‌نخورده بماند).
UPDATE [central].[FiscalYears]
SET StartDate = @StartDate,
    EndDate   = @EndDate,
    IsActive  = 1
WHERE FiscalYearId = @FiscalYearId
  AND [Status] <> N'Closed'
  AND (StartDate <> @StartDate OR EndDate <> @EndDate OR IsActive <> 1);

-- ۴) اعطای دسترسی به کاربر درخواست‌دهنده (برای ادمین صرف‌نظر می‌شود
--    چون ادمین خودکار به همه دسترسی دارد).
IF @UserId IS NOT NULL AND @UserId > 0
   AND EXISTS (SELECT 1 FROM [central].[Users] WHERE UserId = @UserId AND IsDeleted = 0)
   AND NOT EXISTS (SELECT 1 FROM [central].[Users] WHERE UserId = @UserId AND [Role] = N'Admin')
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [central].[UserFiscalYears] WHERE UserId = @UserId AND FiscalYearId = @FiscalYearId)
        INSERT INTO [central].[UserFiscalYears] (UserId, FiscalYearId) VALUES (@UserId, @FiscalYearId);
END

-- ۵) برگرداندن رکورد نهایی.
SELECT
    fy.FiscalYearId,
    fy.CompanyId,
    c.CompanyName,
    fy.YearName,
    fy.StartDate,
    fy.EndDate,
    fy.IsActive,
    fy.[Status],
    fy.CreatedAt,
    fy.UpdatedAt,
    fy.CreatedBy,
    fy.UpdatedBy
FROM [central].[FiscalYears] fy
INNER JOIN [central].[Companies] c ON c.CompanyId = fy.CompanyId AND c.IsDeleted = 0
WHERE fy.FiscalYearId = @FiscalYearId;
