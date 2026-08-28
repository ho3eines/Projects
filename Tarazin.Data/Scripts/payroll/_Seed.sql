-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/payroll/_Seed.sql
-- Schema: payroll
-- Endpoint: execute (startup)
-- =============================================
-- Multi-Company seed: use first company for default data
DECLARE @SeedCompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
IF @SeedCompanyId IS NULL
BEGIN
    -- No company yet — central seed will create it; this seed will run again on next startup
    RETURN;
END


-- EmployeeCode is a GLOBAL unique key, so guard on the codes themselves, not
-- just the company. Deleted companies can leave orphan EMP-xxx rows behind; the
-- global checks keep the seed idempotent across restarts.
IF NOT EXISTS (SELECT 1 FROM [payroll].[Employees] WHERE EmployeeCode IN (N'EMP-001', N'EMP-002', N'EMP-003'))
   AND NOT EXISTS (SELECT 1 FROM [payroll].[Employees] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [payroll].[Employees] (EmployeeCode, FullName, NationalId, Department, BaseSalary, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'EMP-001', N'علی محمدی',   N'10300987654', N'فروش',   85000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'EMP-002', N'مریم احمدی',   N'10300876543', N'حسابداری', 95000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'EMP-003', N'رضا کریمی',    N'10300765432', N'انبار',  72000000, 1, SYSUTCDATETIME(), @SeedCompanyId);
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

-- Period is a GLOBAL unique key, so guard on the period itself as well.
IF NOT EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE Period = N'1405-04')
   AND NOT EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE CompanyId = @SeedCompanyId)
BEGIN
    -- One finalized sample run so the UI is testable on first load.
    INSERT INTO [payroll].[PayrollRuns] (Period, EmployeeCount, NetTotal, Status, CreatedAt, CreatedBy, CompanyId)
    VALUES (N'1405-04', 3, 281400000, N'Finalized', SYSUTCDATETIME(), N'seed', @SeedCompanyId);

    DECLARE @Rid INT = (SELECT TOP 1 RunId FROM [payroll].[PayrollRuns] WHERE Period = N'1405-04');
    INSERT INTO [payroll].[PayrollRunItems] (RunId, EmployeeId, EmployeeName, Amount, CompanyId)
    SELECT @Rid, e.EmployeeId, e.FullName,
           ISNULL((SELECT SUM(Amount) FROM [payroll].[SalaryItems] s
                   WHERE s.EmployeeId = e.EmployeeId AND s.Period = N'1405-04'), 0),
           @SeedCompanyId
    FROM [payroll].[Employees] e;
END

-- ═════════════════════════════════════════════════════════════════
-- Seed: حکم‌های اداری کارمندان موجود
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM [payroll].[EmploymentOrders] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [payroll].[EmploymentOrders]
        (EmployeeId, ContractType, StartDate, BaseSalary, HousingAllowance, FoodAllowance, TransportAllowance,
         InsurancePct, TaxExemptCount, IsActive, CreatedAt, CreatedBy, CompanyId)
    SELECT e.EmployeeId, N'Permanent', '2024-04-01', e.BaseSalary, 9000000, 2000000, 1500000,
           7.00, 0, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId
    FROM [payroll].[Employees] e
    WHERE e.IsActive = 1 AND e.IsDeleted = 0;
END

-- ═════════════════════════════════════════════════════════════════
-- Seed: الگوهای اقلام حقوق (اضافات و کسورات)
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM [payroll].[SalaryTemplates] WHERE CompanyId = @SeedCompanyId)
BEGIN
    -- اضافات (Earnings)
    INSERT INTO [payroll].[SalaryTemplates] (Title, Category, IsPercent, Percentage, FixedAmount, SortOrder, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (N'حقوق پایه',          N'Earning',   0, NULL,  NULL,  1, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'حق مسکن',            N'Earning',   0, NULL,  NULL,  2, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'حق خوراک',           N'Earning',   0, NULL,  NULL,  3, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'حق حمل',             N'Earning',   0, NULL,  NULL,  4, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'فوق‌العاده شغلی',    N'Earning',   0, NULL,  NULL,  5, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'بن‌کارگری',          N'Earning',   0, NULL,  NULL,  6, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'عیدی',               N'Earning',   0, NULL,  NULL,  7, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'پاداش تولید',        N'Earning',   0, NULL,  NULL,  8, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId);

    -- کسورات (Deductions)
    INSERT INTO [payroll].[SalaryTemplates] (Title, Category, IsPercent, Percentage, FixedAmount, SortOrder, IsActive, CreatedAt, CreatedBy, CompanyId)
    VALUES
        (N'بیمه سهم کارمند',    N'Deduction', 1, 7.00,  NULL,  1, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'مالیات بر درآمد',    N'Deduction', 0, NULL,  NULL,  2, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'وام',                 N'Deduction', 0, NULL,  NULL,  3, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'غیبت',                 N'Deduction', 0, NULL,  NULL,  4, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId),
        (N'پیش‌پرداخت',         N'Deduction', 0, NULL,  NULL,  5, 1, SYSUTCDATETIME(), N'seed', @SeedCompanyId);
END