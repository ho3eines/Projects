-- Soft-delete a blog post.
UPDATE [central].[BlogPosts]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE PostId = @PostId AND IsDeleted = 0;
