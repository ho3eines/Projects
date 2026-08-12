-- =============================================
-- Tarazin.Shared/Data/Scripts/payroll/EmployeeList.sql
-- Schema: payroll
-- Query.
-- =============================================
SELECT e.EmployeeId, e.EmployeeCode, e.FullName, e.Department, e.BaseSalary, e.IsActive
FROM [payroll].[Employees] e
WHERE e.IsDeleted = 0
ORDER BY e.FullName;
