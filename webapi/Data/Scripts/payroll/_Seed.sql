-- =============================================
-- webapi/Data/Scripts/payroll/_Seed.sql
-- Schema: payroll
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [payroll].[Employees])
BEGIN
    INSERT INTO [payroll].[Employees] (EmployeeCode, FullName, NationalId, Department, BaseSalary, IsActive, CreatedAt)
    VALUES
        (N'EMP-001', N'علی محمدی',   N'10300987654', N'فروش',   85000000, 1, SYSUTCDATETIME()),
        (N'EMP-002', N'مریم احمدی',   N'10300876543', N'حسابداری', 95000000, 1, SYSUTCDATETIME()),
        (N'EMP-003', N'رضا کریمی',    N'10300765432', N'انبار',  72000000, 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems])
BEGIN
    DECLARE @Period NVARCHAR(20) = N'1405-04';
    INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt)
    SELECT e.EmployeeId, @Period, N'حقوق پایه', e.BaseSalary, 0, SYSUTCDATETIME() FROM [payroll].[Employees] e;
    INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt)
    SELECT e.EmployeeId, @Period, N'حق مسکن و بن', 9000000, 0, SYSUTCDATETIME() FROM [payroll].[Employees] e;
    INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt)
    SELECT e.EmployeeId, @Period, N'بیمه سهم کارمند', e.BaseSalary * 0.07, 1, SYSUTCDATETIME() FROM [payroll].[Employees] e;
END

IF NOT EXISTS (SELECT 1 FROM [payroll].[PayrollRuns])
BEGIN
    -- One finalized sample run so the UI is testable on first load.
    INSERT INTO [payroll].[PayrollRuns] (Period, EmployeeCount, NetTotal, Status, CreatedAt, CreatedBy)
    VALUES (N'1405-04', 3, 281400000, N'Finalized', SYSUTCDATETIME(), N'seed');

    DECLARE @Rid INT = (SELECT TOP 1 RunId FROM [payroll].[PayrollRuns] WHERE Period = N'1405-04');
    INSERT INTO [payroll].[PayrollRunItems] (RunId, EmployeeId, EmployeeName, Amount)
    SELECT @Rid, e.EmployeeId, e.FullName,
           ISNULL((SELECT SUM(Amount) FROM [payroll].[SalaryItems] s
                   WHERE s.EmployeeId = e.EmployeeId AND s.Period = N'1405-04'), 0)
    FROM [payroll].[Employees] e;
END
