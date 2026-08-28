-- =============================================
-- Tarazin.Data/Scripts/inventory/ItemGroupList.sql
-- Schema: inventory
-- Query. فهرست گروه‌های کالا (شرکت فعال).
-- =============================================
SELECT g.GroupId, g.GroupCode, g.Title, g.SortOrder, g.IsActive,
       g.CreatedAt, g.UpdatedAt, g.CreatedBy, g.UpdatedBy,
       (SELECT COUNT(*) FROM [inventory].[Items] i
        WHERE i.GroupId = g.GroupId AND i.IsDeleted = 0) AS ItemCount
FROM [inventory].[ItemGroups] g
WHERE g.IsDeleted = 0 AND g.CompanyId = @CompanyId
ORDER BY g.SortOrder, g.Title;
