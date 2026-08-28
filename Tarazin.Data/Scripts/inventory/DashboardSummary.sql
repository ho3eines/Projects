-- =============================================
-- Tarazin.Data/Scripts/inventory/DashboardSummary.sql
-- Schema: inventory
-- Query. One row of stats (شرکت فعال).
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [inventory].[Movements] WHERE MovementDate = CAST(SYSDATETIME() AS DATE) AND IsDeleted = 0 AND CompanyId = @CompanyId) AS TodayMovements,
    (SELECT COUNT(*) FROM [inventory].[Items] WHERE IsDeleted = 0 AND CompanyId = @CompanyId) AS TotalItems,
    (SELECT ISNULL(SUM(QtyRemaining * UnitCost), 0) FROM [inventory].[StockLayers] WHERE CompanyId = @CompanyId) AS StockValue,
    (SELECT COUNT(*) FROM [inventory].[Reservations] WHERE Status = N'Active') AS ActiveReservations;
