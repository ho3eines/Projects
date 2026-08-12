-- =============================================
-- HermesApp/Data/Scripts/central/BlogUpsert.sql
-- Schema: central
-- Execute. افزودن/ویرایش پست وبلاگ. PostId=0 → insert.
-- =============================================
IF @PostId = 0
BEGIN
    INSERT INTO [central].[BlogPosts] (Title, Slug, Body, Author, Tags, PublishedAt, IsActive, CreatedBy, UpdatedAt)
    VALUES (@Title, @Slug, @Body, @Author, @Tags, @PublishedAt, @IsActive, @CreatedBy, SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [central].[BlogPosts]
    SET Title = @Title, Slug = @Slug, Body = @Body, Author = @Author,
        Tags = @Tags, PublishedAt = @PublishedAt, IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME()
    WHERE PostId = @PostId;
END
