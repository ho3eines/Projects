-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemList.sql
-- Schema: inventory
-- Query. For selects / drop-downs (شرکت فعال + گروه/واحد).
-- =============================================
SELECT i.ItemId, i.ItemCode, i.ItemTitle, i.Category, i.Unit, i.StockQty, i.UnitPrice, i.IsActive,
       i.GroupId, g.Title AS GroupTitle,
       i.UnitId, u.Title AS UnitTitle,
       i.CreatedAt, i.UpdatedAt, i.CreatedBy, i.UpdatedBy,
       i.SKU, i.Barcode, i.Brand, i.Model, i.MinStock, i.MaxStock, i.ReorderPoint,
       i.HasBatch, i.HasSerial, i.HasExpiry, i.LatinTitle, i.PurchasePrice, i.SalePrice,
       i.Description, i.ImageUrl
FROM [inventory].[Items] i
LEFT JOIN [inventory].[ItemGroups] g ON g.GroupId = i.GroupId AND g.IsDeleted = 0
LEFT JOIN [inventory].[Units] u ON u.UnitId = i.UnitId AND u.IsDeleted = 0
WHERE i.IsDeleted = 0 AND i.CompanyId = @CompanyId
  AND (@Search IS NULL OR @Search = N''
       OR i.ItemCode LIKE N'%' + @Search + N'%'
       OR i.ItemTitle LIKE N'%' + @Search + N'%'
       OR i.SKU LIKE N'%' + @Search + N'%'
       OR i.Barcode LIKE N'%' + @Search + N'%'
       OR i.Brand LIKE N'%' + @Search + N'%')
ORDER BY i.ItemTitle;
