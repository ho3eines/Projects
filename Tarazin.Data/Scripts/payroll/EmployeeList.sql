-- =============================================
-- Tarazin.Data/Scripts/payroll/EmployeeList.sql
-- Schema: payroll
-- Query.
-- =============================================
SELECT e.EmployeeId, e.EmployeeCode, e.FullName, e.NationalId, e.Department, e.BaseSalary, e.IsActive,
       e.CompanyId, e.CreatedAt, e.UpdatedAt, e.CreatedBy, e.UpdatedBy
FROM [payroll].[Employees] e
WHERE e.IsDeleted = 0
  AND (@CompanyId IS NULL OR e.CompanyId = @CompanyId)
ORDER BY e.FullName;
