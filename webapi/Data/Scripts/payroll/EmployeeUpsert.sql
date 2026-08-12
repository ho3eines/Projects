-- =============================================
-- webapi/Data/Scripts/payroll/EmployeeUpsert.sql
-- Schema: payroll
-- Execute.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [payroll].[Employees] WHERE EmployeeId = @EmployeeId)
BEGIN
    INSERT INTO [payroll].[Employees] (EmployeeCode, FullName, NationalId, Department, BaseSalary, IsActive, CreatedAt)
    VALUES (@EmployeeCode, @FullName, @NationalId, @Department, ISNULL(@BaseSalary, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [payroll].[Employees]
    SET EmployeeCode = ISNULL(@EmployeeCode, EmployeeCode),
        FullName     = ISNULL(@FullName, FullName),
        NationalId   = @NationalId,
        Department   = @Department,
        BaseSalary   = @BaseSalary,
        IsActive     = ISNULL(@IsActive, IsActive),
        UpdatedAt    = SYSUTCDATETIME()
    WHERE EmployeeId = @EmployeeId;
END
