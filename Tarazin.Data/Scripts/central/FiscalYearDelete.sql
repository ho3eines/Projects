-- =============================================
-- Tarazin.Data/Scripts/central/FiscalYearDelete.sql
-- Schema: central
-- Execute. حذف نرم سال مالی.
--
-- ⚠ حذف سال مالی برای سال‌هایی که سند دارند یا بسته شده‌اند ممنوع است.
--   (این اسکریپت از مسیر UI فعلی فراخوانی نمی‌شود، ولی برای حفاظت
--    در سطح Data Access نگه داشته شده است.)
-- =============================================
IF EXISTS (
    SELECT 1 FROM [accounting].[Documents]
    WHERE FiscalYearId = @FiscalYearId AND IsDeleted = 0
)
    THROW 51112, N'سال مالی دارای سند است و قابل حذف نیست.', 1;

IF EXISTS (
    SELECT 1 FROM [central].[FiscalYears]
    WHERE FiscalYearId = @FiscalYearId AND ISNULL([Status], N'Open') = N'Closed'
)
    THROW 51113, N'سال مالی بسته شده است و قابل حذف نیست.', 1;

UPDATE [central].[FiscalYears]
SET IsDeleted = 1,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy
WHERE FiscalYearId = @FiscalYearId;
