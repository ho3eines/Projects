-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemList.sql
-- Schema: inventory
-- Query. For selects / drop-downs (شرکت فعال + گروه/واحد).
-- =============================================
SELECT i.ItemId, i.ItemCode, i.ItemTitle, i.Category, i.Unit, i.StockQty, i.UnitPrice, i.IsActive,
       i.GroupId, g.Title AS GroupTitle,
       i.UnitId, u.Title AS UnitTitle,
       i.CreatedAt, i.UpdatedAt, i.CreatedBy, i.UpdatedBy
FROM [inventory].[Items] i
LEFT JOIN [inventory].[ItemGroups] g ON g.GroupId = i.GroupId AND g.IsDeleted = 0
LEFT JOIN [inventory].[Units] u ON u.UnitId = i.UnitId AND u.IsDeleted = 0
WHERE i.IsDeleted = 0 AND i.CompanyId = @CompanyId
ORDER BY i.ItemTitle;
