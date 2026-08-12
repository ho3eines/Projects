-- =============================================
-- webapi/Data/Scripts/inventory/DashboardSummary.sql
-- Schema: inventory
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [inventory].[Movements] WHERE MovementDate = CAST(SYSDATETIME() AS DATE) AND IsDeleted = 0) AS TodayMovements,
    (SELECT COUNT(*) FROM [inventory].[Items] WHERE IsDeleted = 0) AS TotalItems,
    (SELECT ISNULL(SUM(StockQty * UnitPrice), 0) FROM [inventory].[Items] WHERE IsDeleted = 0) AS StockValue,
    (SELECT COUNT(*) FROM [inventory].[Reservations] WHERE Status = N'Active') AS ActiveReservations;
