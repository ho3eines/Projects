-- =============================================
-- Tarazin.Data/Scripts/payroll/EmployeeUpsert.sql
-- Schema: payroll
-- Execute.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(30) = ISNULL(NULLIF(@EmployeeCode, N''),
    N'EMP-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(EmployeeId) FROM [payroll].[Employees]), 0) + 1 AS NVARCHAR(10)), 5));

-- EmployeeId=0 identifies a new record; every non-zero id is an edit.
IF @EmployeeId = 0
BEGIN
    INSERT INTO [payroll].[Employees] (EmployeeCode, FullName, NationalId, Department, BaseSalary, IsActive, CreatedAt, CompanyId)
    VALUES (@EffectiveCode, @FullName, @NationalId, @Department, ISNULL(@BaseSalary, 0), ISNULL(@IsActive, 1), SYSUTCDATETIME(), @CompanyId);
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
    WHERE EmployeeId = @EmployeeId AND (@CompanyId IS NULL OR CompanyId = @CompanyId);
END
