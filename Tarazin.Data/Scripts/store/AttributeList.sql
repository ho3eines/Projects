-- =============================================
-- Tarazin.Data/Scripts/store/AttributeList.sql
-- Schema: store
-- Query. فهرست ویژگی‌ها (+گروه) برای مدیریت و فرم محصول.
-- =============================================
SELECT
    a.AttributeId,
    a.CompanyId,
    a.AttributeGroupId,
    g.Title AS GroupTitle,
    a.Title,
    a.DataType,
    a.Unit,
    a.IsVariantFacet,
    a.SortOrder,
    a.IsActive
FROM [store].[Attributes] a
LEFT JOIN [store].[AttributeGroups] g ON g.AttributeGroupId = a.AttributeGroupId
WHERE a.CompanyId = @CompanyId
  AND a.IsDeleted = 0
  AND (@AttributeId IS NULL OR a.AttributeId = @AttributeId)
  AND (@FacetOnly IS NULL OR @FacetOnly = 0 OR a.IsVariantFacet = 1)
ORDER BY g.SortOrder, a.SortOrder, a.Title;
