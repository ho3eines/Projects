-- =============================================
-- Tarazin.Data/Scripts/payroll/SalaryItemListCompany.sql
-- Schema: payroll
-- Query. اقلام حقوق یک کارمند در یک دوره (فیلتر با CompanyId)
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
    s.UpdatedBy,
    s.CompanyId
FROM [payroll].[SalaryItems] s
WHERE s.EmployeeId = @EmployeeId
  AND s.Period = @Period
  AND (@CompanyId IS NULL OR s.CompanyId = @CompanyId)
ORDER BY s.IsDeduction ASC, s.SalaryItemId ASC;
