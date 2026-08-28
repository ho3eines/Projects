-- Close a finalized payroll period. Closing is irreversible by design.
IF NOT EXISTS (
    SELECT 1 FROM [payroll].[PayrollRuns]
    WHERE RunId = @RunId AND (@CompanyId IS NULL OR CompanyId = @CompanyId))
    THROW 51031, N'دوره حقوق پیدا نشد', 1;

IF EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE RunId = @RunId AND Status = N'Closed')
    THROW 51032, N'این دوره قبلاً بسته شده است', 1;

IF NOT EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE RunId = @RunId AND Status = N'Finalized')
    THROW 51033, N'فقط دوره نهایی‌شده قابل بستن است', 1;

UPDATE [payroll].[PayrollRuns]
SET Status = N'Closed', LockedAt = SYSUTCDATETIME(), LockedBy = @UpdatedBy,
    UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
WHERE RunId = @RunId AND (@CompanyId IS NULL OR CompanyId = @CompanyId);
