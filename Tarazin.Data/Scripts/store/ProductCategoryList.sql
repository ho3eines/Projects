-- =============================================
-- Tarazin.Data/Scripts/store/ProductCategoryList.sql
-- Schema: store
-- Query.
-- =============================================
SELECT c.CategoryId, c.CategoryCode, c.Title, c.SortOrder, c.IsActive,
       c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
FROM [store].[ProductCategories] c
WHERE c.IsDeleted = 0
ORDER BY c.SortOrder, c.Title;
