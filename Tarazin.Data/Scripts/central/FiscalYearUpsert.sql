-- =============================================
-- Tarazin.Data/Scripts/central/FiscalYearUpsert.sql
-- Schema: central
-- Execute. ویرایش سال مالی موجود.
--
-- ⚠ مهم: ایجاد سال مالی دیگر توسط کاربر انجام نمی‌شود. این اسکریپت فقط
--   حالت «ویرایش» (FiscalYearId > 0) را می‌پذیرد؛ درج دستی با خطا
--   رد می‌شود. مسیر سیستمیِ ایجاد سال مالی «FiscalYearEnsure» است.
-- =============================================
IF @FiscalYearId IS NULL OR @FiscalYearId <= 0
    THROW 51110, N'ایجاد سال مالی به‌صورت دستی مجاز نیست. سال مالی توسط سیستم به‌صورت خودکار ایجاد می‌شود.', 1;

IF NOT EXISTS (SELECT 1 FROM [central].[FiscalYears] WHERE FiscalYearId = @FiscalYearId AND IsDeleted = 0)
    THROW 51111, N'سال مالی یافت نشد یا حذف شده است.', 1;

UPDATE [central].[FiscalYears]
SET YearName = @YearName,
    StartDate = @StartDate,
    EndDate = @EndDate,
    IsActive = @IsActive,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @CreatedBy
WHERE FiscalYearId = @FiscalYearId AND IsDeleted = 0;

SELECT @FiscalYearId AS NewId;
