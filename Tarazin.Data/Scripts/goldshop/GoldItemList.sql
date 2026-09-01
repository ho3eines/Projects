-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldItemList.sql
-- Schema: goldshop
-- Query.
-- =============================================
SELECT g.GoldItemId, g.ItemCode, g.Title, g.Purity, g.InventoryItemCode, g.IsActive,
       i.ItemTitle AS InventoryItemTitle,
       g.CreatedAt, g.UpdatedAt, g.CreatedBy, g.UpdatedBy
FROM [goldshop].[GoldItems] g
LEFT JOIN [inventory].[Items] i ON i.ItemCode = g.InventoryItemCode AND i.CompanyId = g.CompanyId AND i.IsDeleted = 0
WHERE g.IsDeleted = 0 AND g.CompanyId = @CompanyId
ORDER BY g.Title;
