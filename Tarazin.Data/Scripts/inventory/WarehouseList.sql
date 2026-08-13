-- =============================================
-- Tarazin.Data/Scripts/inventory/WarehouseList.sql
-- Schema: inventory
-- Query.
-- =============================================
SELECT w.WarehouseId, w.WarehouseCode, w.Title, w.Location, w.IsActive,
       w.CreatedAt, w.UpdatedAt, w.CreatedBy, w.UpdatedBy
FROM [inventory].[Warehouses] w
WHERE w.IsDeleted = 0
ORDER BY w.Title;
