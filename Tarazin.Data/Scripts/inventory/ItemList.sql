-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemList.sql
-- Schema: inventory
-- Query. For selects / drop-downs.
-- =============================================
SELECT i.ItemId, i.ItemCode, i.ItemTitle, i.Unit, i.StockQty, i.UnitPrice
FROM [inventory].[Items] i
WHERE i.IsDeleted = 0
ORDER BY i.ItemTitle;
