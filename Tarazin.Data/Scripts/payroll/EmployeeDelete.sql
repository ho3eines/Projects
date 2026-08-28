-- Soft-delete an employee while preserving payroll history.
UPDATE [payroll].[Employees]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE EmployeeId = @EmployeeId AND IsDeleted = 0
  AND (@CompanyId IS NULL OR CompanyId = @CompanyId);
