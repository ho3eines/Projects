-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryItemDelete.sql
-- Schema: payroll
-- Execute. حذف قلم حقوق.
-- =============================================
DELETE FROM [payroll].[SalaryItems]
WHERE SalaryItemId = @SalaryItemId
  AND EXISTS (SELECT 1 FROM [payroll].[Employees] e WHERE e.EmployeeId = (SELECT EmployeeId FROM [payroll].[SalaryItems] WHERE SalaryItemId = @SalaryItemId) AND (@CompanyId IS NULL OR e.CompanyId = @CompanyId));