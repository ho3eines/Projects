-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryItemList.sql
-- Schema: payroll
-- Query. اقلام حقوق (مزایا/کسورات) یک کارمند در یک دوره.
-- =============================================
SELECT
    s.SalaryItemId,
    s.EmployeeId,
    s.Period,
    s.Title,
    s.Amount,
    s.IsDeduction,
    s.CreatedAt,
    s.UpdatedAt,
    s.CreatedBy,
    s.UpdatedBy
FROM [payroll].[SalaryItems] s
WHERE s.EmployeeId = @EmployeeId
  AND s.Period = @Period
  AND (@CompanyId IS NULL OR s.EmployeeId IN (
      SELECT e.EmployeeId FROM [payroll].[Employees] e
      WHERE e.CompanyId = @CompanyId AND e.IsDeleted = 0
  ))
ORDER BY s.IsDeduction ASC, s.SalaryItemId ASC;