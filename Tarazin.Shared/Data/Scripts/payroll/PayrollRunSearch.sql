-- =============================================
-- Tarazin.Shared/Data/Scripts/payroll/PayrollRunSearch.sql
-- Schema: payroll | Contract: PayrollRun
-- Query. Shape MUST match PayrollRunRow (Share) exactly.
-- =============================================
SELECT
    r.RunId,
    r.Period,
    r.EmployeeCount,
    r.NetTotal,
    r.Status,
    r.CreatedAt
FROM [payroll].[PayrollRuns] r
ORDER BY r.RunId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
