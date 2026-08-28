-- =============================================
-- Tarazin.Data/Scripts/payroll/DashboardSummary.sql
-- Schema: payroll
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsActive = 1 AND IsDeleted = 0
       AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS ActiveEmployees,
    (SELECT COUNT(*) FROM [payroll].[PayrollRuns]
       WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS TotalRuns,
    (SELECT ISNULL(SUM(NetTotal), 0) FROM [payroll].[PayrollRuns]
       WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS TotalPaid,
    (SELECT TOP 1 Period FROM [payroll].[PayrollRuns]
       WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)
       ORDER BY RunId DESC) AS LatestPeriod;
