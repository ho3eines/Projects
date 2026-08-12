-- Soft-delete a customer while preserving order history.
UPDATE [store].[Customers]
SET IsDeleted = 1, IsActive = 0
WHERE CustomerId = @CustomerId AND IsDeleted = 0;
