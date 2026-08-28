-- Soft-delete an item while preserving stock movement history.
UPDATE [inventory].[Items]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE ItemId = @ItemId AND CompanyId = @CompanyId AND IsDeleted = 0;
