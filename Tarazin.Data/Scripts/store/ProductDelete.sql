-- Soft-delete a product while preserving order history.
UPDATE [store].[Products]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE ProductId = @ProductId AND IsDeleted = 0;
