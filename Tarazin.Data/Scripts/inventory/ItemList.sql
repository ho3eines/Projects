-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemList.sql
-- Schema: inventory
-- Query. For selects / drop-downs.
-- =============================================
SELECT i.ItemId, i.ItemCode, i.ItemTitle, i.Category, i.Unit, i.StockQty, i.UnitPrice, i.IsActive
FROM [inventory].[Items] i
WHERE i.IsDeleted = 0
ORDER BY i.ItemTitle;
