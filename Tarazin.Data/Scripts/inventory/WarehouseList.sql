-- =============================================
-- Tarazin.Data/Scripts/inventory/WarehouseList.sql
-- Schema: inventory
-- Query.
-- =============================================
SELECT w.WarehouseId, w.WarehouseCode, w.Title, w.Location, w.IsActive
FROM [inventory].[Warehouses] w
WHERE w.IsDeleted = 0
ORDER BY w.Title;
