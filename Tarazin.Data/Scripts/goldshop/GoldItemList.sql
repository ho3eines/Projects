-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldItemList.sql
-- Schema: goldshop
-- Query.
-- =============================================
SELECT g.GoldItemId, g.ItemCode, g.Title, g.Purity, g.IsActive,
       g.CreatedAt, g.UpdatedAt, g.CreatedBy, g.UpdatedBy
FROM [goldshop].[GoldItems] g
WHERE g.IsDeleted = 0
ORDER BY g.Title;
