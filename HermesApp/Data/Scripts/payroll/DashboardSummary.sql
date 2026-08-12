-- =============================================
-- HermesApp/Data/Scripts/payroll/DashboardSummary.sql
-- Schema: payroll
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsActive = 1 AND IsDeleted = 0) AS ActiveEmployees,
    (SELECT COUNT(*) FROM [payroll].[PayrollRuns]) AS TotalRuns,
    (SELECT ISNULL(SUM(NetTotal), 0) FROM [payroll].[PayrollRuns]) AS TotalPaid,
    (SELECT TOP 1 Period FROM [payroll].[PayrollRuns] ORDER BY RunId DESC) AS LatestPeriod;
