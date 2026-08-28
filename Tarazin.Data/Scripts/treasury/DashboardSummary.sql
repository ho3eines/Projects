-- =============================================
-- Tarazin.Data/Scripts/treasury/DashboardSummary.sql
-- Schema: treasury
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT ISNULL(SUM(CASE WHEN Direction = N'In' THEN Amount ELSE -Amount END), 0)
     FROM [treasury].[CashMovements] WHERE MovementDate = CAST(SYSDATETIME() AS DATE) AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS TodayNet,
    (SELECT ISNULL(SUM(Balance), 0) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0 AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS BankBalance,
    (SELECT ISNULL(SUM(Balance), 0) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0 AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS CashBalance,
    (SELECT COUNT(*) FROM [treasury].[Cheques] WHERE Status = N'Pending' AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS PendingCheques,
    (SELECT COUNT(*) FROM [treasury].[Cheques]
     WHERE Status IN (N'Pending', N'Collecting') AND DueDate < CAST(SYSDATETIME() AS DATE)
       AND (@CompanyId IS NULL OR CompanyId = @CompanyId)) AS OverdueCheques;
