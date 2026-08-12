-- Soft-delete a news item.
UPDATE [central].[News]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE NewsId = @NewsId AND IsDeleted = 0;
