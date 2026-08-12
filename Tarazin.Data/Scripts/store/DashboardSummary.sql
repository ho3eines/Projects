-- =============================================
-- Tarazin.Data/Scripts/store/DashboardSummary.sql
-- Schema: store
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [store].[Orders] WHERE OrderDate = CAST(SYSDATETIME() AS DATE)) AS TodayOrders,
    (SELECT ISNULL(SUM(TotalAmount), 0) FROM [store].[Orders] WHERE OrderDate = CAST(SYSDATETIME() AS DATE)) AS TodayAmount,
    (SELECT COUNT(*) FROM [store].[Orders] WHERE Status = N'Placed') AS PendingOrders,
    (SELECT COUNT(*) FROM [store].[Customers] WHERE IsDeleted = 0) AS TotalCustomers;
