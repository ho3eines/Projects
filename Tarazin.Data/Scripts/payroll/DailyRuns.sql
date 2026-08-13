-- =============================================
-- Tarazin.Data/Scripts/payroll/DailyRuns.sql
-- Schema: payroll
-- Query. Main page grid (آخرین دوره‌ها).
-- =============================================
SELECT
    r.RunId,
    r.Period,
    r.EmployeeCount,
    r.NetTotal,
    r.Status,
    r.CreatedAt,
    r.UpdatedAt,
    r.CreatedBy,
    r.UpdatedBy
FROM [payroll].[PayrollRuns] r
ORDER BY r.RunId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
