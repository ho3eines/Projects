-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/store/_Seed.sql
-- Schema: store
-- Endpoint: execute (startup)
-- =============================================
-- Multi-Company seed: use first company for default data
DECLARE @SeedCompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
IF @SeedCompanyId IS NULL
BEGIN
    -- No company yet — central seed will create it; this seed will run again on next startup
    RETURN;
END


-- CustomerCode/ProductCode/OrderNumber are GLOBAL unique keys, so guard on the
-- codes themselves, not just the company. Deleted companies can leave orphan
-- rows behind; global checks keep the seed idempotent across restarts.
IF NOT EXISTS (SELECT 1 FROM [store].[Customers] WHERE CustomerCode IN (N'CST-001', N'CST-002'))
   AND NOT EXISTS (SELECT 1 FROM [store].[Customers] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [store].[Customers] (CustomerCode, FullName, Phone, Email, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'CST-001', N'سارا رضایی', N'09121234567', N'sara@example.ir', 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'CST-002', N'حسین نوری',  N'09351112233', N'hossein@example.ir', 1, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [store].[Products] WHERE ProductCode IN (N'P-GOLD24', N'P-GOLD18', N'P-CHAIN'))
   AND NOT EXISTS (SELECT 1 FROM [store].[Products] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [store].[Products] (ProductCode, Title, ItemCode, Price, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'P-GOLD24', N'سکه طلا (امامی) — ۱ عدد', N'SIKKEH', 62000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'P-GOLD18', N'طلای ۱۸ عیار — ۱ گرم',    N'GOLD-18', 28000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'P-CHAIN',  N'زنجیر طلا طرح دار',        N'CHAIN-01', 45000000, 1, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [store].[Orders] WHERE OrderNumber = N'ORD-00001')
   AND NOT EXISTS (SELECT 1 FROM [store].[Orders] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [store].[Orders] (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount, TotalAmount, CurrencyCode, Status, CreatedAt, CompanyId)
    VALUES (N'ORD-00001', 1, N'سارا رضایی', CAST(SYSDATETIME() AS DATE), 1, 62000000, N'IRR', N'Placed', SYSUTCDATETIME(), @SeedCompanyId);

    INSERT INTO [store].[OrderItems] (OrderId, ProductId, ProductTitle, Qty, UnitPrice, CompanyId)
    SELECT (SELECT TOP 1 OrderId FROM [store].[Orders] ORDER BY OrderId DESC), ProductId, Title, 1, Price, @SeedCompanyId
    FROM [store].[Products] WHERE ProductCode = N'P-GOLD24';
END

-- Cart sample so the "ثبت سفارش" flow has something to place.
IF NOT EXISTS (SELECT 1 FROM [store].[CartItems] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [store].[CartItems] (CustomerId, ProductId, Qty, AddedAt, CompanyId)
    VALUES (2, 2, 2, SYSUTCDATETIME(), @SeedCompanyId);
END