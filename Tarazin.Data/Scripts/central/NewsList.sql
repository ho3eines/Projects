-- =============================================
-- Tarazin.Data/Scripts/central/NewsList.sql
-- Schema: central
-- Query. اخبار شرکت (پلتفرم مشترک).
-- =============================================
SELECT
    n.NewsId,
    n.Title,
    n.Summary,
    n.Body,
    n.ImageUrl,
    n.PublishedAt,
    n.IsActive,
    n.CreatedAt,
    n.UpdatedAt,
    n.CreatedBy,
    n.UpdatedBy
FROM [central].[News] n
WHERE n.IsDeleted = 0
ORDER BY ISNULL(n.PublishedAt, n.CreatedAt) DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
