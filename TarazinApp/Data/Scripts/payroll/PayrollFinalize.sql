-- =============================================
-- TarazinApp/Data/Scripts/payroll/PayrollFinalize.sql
-- Schema: payroll
-- Execute. عملیات ویژه: محاسبه و نهایی‌کردن دوره + رویداد PayrollFinalized
-- (ADR-002 dual-write → accounting.GLPostFromPayroll + treasury.CashMoveFromPayroll).
-- =============================================
IF EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE Period = @Period)
    THROW 51020, N'این دوره قبلاً نهایی شده است', 1;

BEGIN TRAN;
    INSERT INTO [payroll].[PayrollRuns] (Period, EmployeeCount, NetTotal, Status, CreatedAt, CreatedBy)
    SELECT
        @Period,
        (SELECT COUNT(DISTINCT EmployeeId) FROM [payroll].[SalaryItems] WHERE Period = @Period),
        (SELECT ISNULL(SUM(CASE WHEN IsDeduction = 1 THEN -Amount ELSE Amount END), 0)
         FROM [payroll].[SalaryItems] WHERE Period = @Period),
        N'Finalized', SYSUTCDATETIME(), @CreatedBy;

    DECLARE @Rid INT = SCOPE_IDENTITY();

    INSERT INTO [payroll].[PayrollRunItems] (RunId, EmployeeId, EmployeeName, Amount)
    SELECT @Rid, e.EmployeeId, e.FullName,
           ISNULL((SELECT SUM(CASE WHEN s.IsDeduction = 1 THEN -s.Amount ELSE s.Amount END)
                   FROM [payroll].[SalaryItems] s
                   WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period), 0)
    FROM [payroll].[Employees] e
    WHERE e.IsActive = 1
      AND EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period);

    DECLARE @Net DECIMAL(18,2) = (SELECT NetTotal FROM [payroll].[PayrollRuns] WHERE RunId = @Rid);
    DECLARE @EmpCount INT = (SELECT EmployeeCount FROM [payroll].[PayrollRuns] WHERE RunId = @Rid);

    INSERT INTO [payroll].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'PayrollFinalized', CONCAT(N'RunId=', @Rid),
        (SELECT @Rid AS RunId, @Period AS Period, @EmpCount AS EmployeeCount, @Net AS NetTotal
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
COMMIT;
