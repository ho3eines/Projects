-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldItemList.sql
-- Schema: goldshop
-- Query.
-- =============================================
SELECT g.GoldItemId, g.ItemCode, g.Title, g.Purity, g.InventoryItemCode, g.IsActive,
       g.CreatedAt, g.UpdatedAt, g.CreatedBy, g.UpdatedBy
FROM [goldshop].[GoldItems] g
WHERE g.IsDeleted = 0 AND g.CompanyId = @CompanyId
ORDER BY g.Title;
