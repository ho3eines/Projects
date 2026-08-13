-- Soft-delete a gallery item.
UPDATE [central].[GalleryItems]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE GalleryItemId = @GalleryItemId AND IsDeleted = 0;
