-- Soft-delete a user account. Keep at least one active administrator.
IF EXISTS (
    SELECT 1 FROM [central].[Users]
    WHERE UserId = @UserId AND Role = N'Admin' AND IsActive = 1 AND IsDeleted = 0)
AND NOT EXISTS (
    SELECT 1 FROM [central].[Users]
    WHERE UserId <> @UserId AND Role = N'Admin' AND IsActive = 1 AND IsDeleted = 0)
    THROW 51051, N'آخرین مدیر فعال سیستم قابل حذف نیست', 1;

UPDATE [central].[Users]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE UserId = @UserId AND IsDeleted = 0;
