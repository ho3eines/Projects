-- =============================================
-- webapi/Data/Scripts/store/ProductList.sql
-- Schema: store
-- Query.
-- =============================================
SELECT p.ProductId, p.ProductCode, p.Title, p.ItemCode, p.Price, p.IsActive
FROM [store].[Products] p
WHERE p.IsDeleted = 0
ORDER BY p.Title;
