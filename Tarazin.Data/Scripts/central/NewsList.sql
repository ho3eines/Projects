-- =============================================
-- Tarazin.Data/Scripts/central/NewsList.sql
-- Schema: central
-- Query. اخبار شرکت (پلتفرم مشترک).
-- =============================================
SELECT
    n.NewsId,
    n.Title,
    n.Summary,
    n.ImageUrl,
    n.PublishedAt,
    n.IsActive,
    n.CreatedAt
FROM [central].[News] n
WHERE n.IsDeleted = 0
ORDER BY ISNULL(n.PublishedAt, n.CreatedAt) DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
