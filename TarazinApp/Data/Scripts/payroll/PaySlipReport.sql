-- =============================================
-- TarazinApp/Data/Scripts/payroll/PaySlipReport.sql
-- Schema: payroll
-- Query. فیش حقوق یک دوره.
-- =============================================
SELECT
    ri.RunItemId,
    ri.EmployeeId,
    ri.EmployeeName,
    ri.Amount AS NetPay,
    r.Period,
    r.EmployeeCount,
    r.NetTotal,
    r.CreatedAt
FROM [payroll].[PayrollRunItems] ri
JOIN [payroll].[PayrollRuns] r ON r.RunId = ri.RunId
WHERE ri.RunId = @RunId
ORDER BY ri.EmployeeName;
