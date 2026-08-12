-- =============================================
-- Tarazin.Shared/Data/Scripts/central/GalleryUpsert.sql
-- Schema: central
-- Execute. افزودن/ویرایش آیتم گالری. GalleryItemId=0 → insert.
-- =============================================
IF @GalleryItemId = 0
BEGIN
    INSERT INTO [central].[GalleryItems] (Title, ImageUrl, Caption, SortOrder, IsActive, CreatedBy)
    VALUES (@Title, @ImageUrl, @Caption, @SortOrder, @IsActive, @CreatedBy);
END
ELSE
BEGIN
    UPDATE [central].[GalleryItems]
    SET Title = @Title, ImageUrl = @ImageUrl, Caption = @Caption,
        SortOrder = @SortOrder, IsActive = @IsActive
    WHERE GalleryItemId = @GalleryItemId;
END
