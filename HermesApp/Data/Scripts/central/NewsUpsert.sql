-- =============================================
-- HermesApp/Data/Scripts/central/NewsUpsert.sql
-- Schema: central
-- Execute. افزودن/ویرایش خبر. NewsId=0 → insert.
-- =============================================
IF @NewsId = 0
BEGIN
    INSERT INTO [central].[News] (Title, Summary, Body, ImageUrl, PublishedAt, IsActive, CreatedBy, UpdatedAt)
    VALUES (@Title, @Summary, @Body, @ImageUrl, @PublishedAt, @IsActive, @CreatedBy, SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE [central].[News]
    SET Title = @Title, Summary = @Summary, Body = @Body, ImageUrl = @ImageUrl,
        PublishedAt = @PublishedAt, IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME()
    WHERE NewsId = @NewsId;
END
