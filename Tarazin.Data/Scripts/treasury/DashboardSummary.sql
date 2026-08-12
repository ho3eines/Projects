-- =============================================
-- Tarazin.Data/Scripts/treasury/DashboardSummary.sql
-- Schema: treasury
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT ISNULL(SUM(CASE WHEN Direction = N'In' THEN Amount ELSE -Amount END), 0)
     FROM [treasury].[CashMovements] WHERE MovementDate = CAST(SYSDATETIME() AS DATE)) AS TodayNet,
    (SELECT ISNULL(SUM(Balance), 0) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0) AS BankBalance,
    (SELECT ISNULL(SUM(Balance), 0) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0) AS CashBalance,
    (SELECT COUNT(*) FROM [treasury].[Cheques] WHERE Status = N'Pending') AS PendingCheques;
