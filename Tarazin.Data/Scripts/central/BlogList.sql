-- =============================================
-- Tarazin.Data/Scripts/central/BlogList.sql
-- Schema: central
-- Query. پست‌های وبلاگ (پلتفرم مشترک).
-- =============================================
SELECT
    b.PostId,
    b.Title,
    b.Slug,
    b.Body,
    b.Author,
    b.Tags,
    b.PublishedAt,
    b.IsActive,
    b.CreatedAt,
    b.UpdatedAt,
    b.CreatedBy,
    b.UpdatedBy
FROM [central].[BlogPosts] b
WHERE b.IsDeleted = 0
ORDER BY ISNULL(b.PublishedAt, b.CreatedAt) DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
