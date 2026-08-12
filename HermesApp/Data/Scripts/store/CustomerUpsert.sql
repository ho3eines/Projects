-- =============================================
-- HermesApp/Data/Scripts/store/CustomerUpsert.sql
-- Schema: store
-- Execute.
-- =============================================
DECLARE @EffectiveCode NVARCHAR(30) = ISNULL(NULLIF(@CustomerCode, N''),
    N'CST-' + RIGHT(N'00000' + CAST(ISNULL((SELECT MAX(CustomerId) FROM [store].[Customers]), 0) + 1 AS NVARCHAR(10)), 5));

IF NOT EXISTS (SELECT 1 FROM [store].[Customers] WHERE CustomerId = @CustomerId)
BEGIN
    INSERT INTO [store].[Customers] (CustomerCode, FullName, Phone, Email, IsActive, CreatedAt)
    VALUES (@EffectiveCode, @FullName, @Phone, @Email, ISNULL(@IsActive, 1), SYSUTCDATETIME());
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
