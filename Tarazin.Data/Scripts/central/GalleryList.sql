-- =============================================
-- Tarazin.Data/Scripts/central/GalleryList.sql
-- Schema: central
-- Query. گالری وبسایت (پلتفرم مشترک).
-- =============================================
SELECT
    g.GalleryItemId,
    g.Title,
    g.ImageUrl,
    g.Caption,
    g.SortOrder,
    g.IsActive,
    g.CreatedAt
FROM [central].[GalleryItems] g
WHERE g.IsDeleted = 0
ORDER BY g.SortOrder, g.GalleryItemId
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
