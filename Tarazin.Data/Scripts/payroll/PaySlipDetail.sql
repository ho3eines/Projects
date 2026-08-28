-- =============================================
-- Tarazin.Data/Scripts/payroll/PaySlipDetail.sql
-- Schema: payroll
-- Query. فیش حقوق یک دوره با تجمیع اقلام هر کارمند.
--
-- برای هر کارمندِ دوره: خالص ذخیره‌شده در RunItems + تسهیم‌ها و کسورات دوره
-- (از SalaryItems همدوره). مالیات/خالص نهایی در سمت C# با PayrollCalculationService
-- محاسبه می‌شود (جدول پلکانی در سرویس مالیات است)، بنابراین اینجا فقط aggregations
-- خام بر می‌گردند.
-- =============================================
SELECT
    r.RunId,
    r.Period,
    r.EmployeeCount,
    r.NetTotal,
    ri.EmployeeId,
    ri.EmployeeName,
    ri.Amount AS StoredNet,
    ISNULL((SELECT SUM(s.Amount) FROM [payroll].[SalaryItems] s
            WHERE s.EmployeeId = ri.EmployeeId AND s.Period = r.Period AND s.IsDeduction = 0), 0) AS TotalEarnings,
    ISNULL((SELECT SUM(s.Amount) FROM [payroll].[SalaryItems] s
            WHERE s.EmployeeId = ri.EmployeeId AND s.Period = r.Period AND s.IsDeduction = 1), 0) AS TotalDeductions
FROM [payroll].[PayrollRunItems] ri
JOIN [payroll].[PayrollRuns] r ON r.RunId = ri.RunId
WHERE ri.RunId = @RunId
  AND (@CompanyId IS NULL OR r.CompanyId = @CompanyId)
ORDER BY ri.EmployeeName;