-- =============================================
-- webapi/Data/Scripts/store/CustomerUpsert.sql
-- Schema: store
-- Execute.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[Customers] WHERE CustomerId = @CustomerId)
BEGIN
    INSERT INTO [store].[Customers] (CustomerCode, FullName, Phone, Email, IsActive, CreatedAt)
    VALUES (@CustomerCode, @FullName, @Phone, @Email, ISNULL(@IsActive, 1), SYSUTDATETIME());
END
ELSE
BEGIN
    UPDATE [store].[Customers]
    SET CustomerCode = ISNULL(@CustomerCode, CustomerCode),
        FullName     = ISNULL(@FullName, FullName),
        Phone        = @Phone,
        Email        = @Email,
        IsActive     = ISNULL(@IsActive, IsActive)
    WHERE CustomerId = @CustomerId;
END
