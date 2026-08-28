-- =============================================
-- Tarazin.Data/Scripts/payroll/PayrollReopenPeriod.sql
-- Schema: payroll
-- Execute. بازگشایی دوره نهایی‌شده (Finalized → Draft)
--
-- فقط دوره‌های Finalized قابل بازگشایی هستند.
-- دوره‌های Closed غیرقابل برگشت هستند.
-- =============================================
DECLARE @CurrentStatus NVARCHAR(30);
SELECT @CurrentStatus = Status FROM [payroll].[PayrollRuns] WHERE RunId = @RunId;

IF @CurrentStatus IS NULL
    THROW 51022, N'دوره یافت نشد', 1;

IF @CurrentStatus = N'Closed'
    THROW 51023, N'دوره بسته‌شده قابل بازگشایی نیست', 1;

IF @CurrentStatus = N'Draft'
    THROW 51024, N'دوره همین حالا در وضعیت Draft است', 1;

-- Finalized → Draft یا Reopened → Draft
UPDATE [payroll].[PayrollRuns]
SET Status = N'Draft',
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy,
    LockedAt = NULL,
    LockedBy = NULL
WHERE RunId = @RunId;
