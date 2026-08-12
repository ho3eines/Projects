-- Soft-delete a chart-of-account row while preserving journal history.
UPDATE [accounting].[ChartOfAccounts]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE AccountId = @AccountId AND IsDeleted = 0;
