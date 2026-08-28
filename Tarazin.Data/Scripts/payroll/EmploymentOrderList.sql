-- =============================================
-- Tarazin.Data/Scripts/payroll/EmploymentOrderList.sql
-- Schema: payroll
-- Query. لیست حکم‌های اداری کارمندان
-- =============================================
SELECT
    eo.OrderId,
    eo.EmployeeId,
    e.EmployeeCode,
    e.FullName AS EmployeeName,
    e.Department,
    eo.ContractType,
    eo.StartDate,
    eo.EndDate,
    eo.BaseSalary,
    eo.HousingAllowance,
    eo.FoodAllowance,
    eo.TransportAllowance,
    eo.InsurancePct,
    eo.TaxExemptCount,
    eo.IsActive,
    eo.Notes,
    eo.CreatedAt,
    eo.UpdatedAt,
    eo.CompanyId
FROM [payroll].[EmploymentOrders] eo
JOIN [payroll].[Employees] e ON e.EmployeeId = eo.EmployeeId
WHERE e.IsDeleted = 0
ORDER BY e.FullName;
