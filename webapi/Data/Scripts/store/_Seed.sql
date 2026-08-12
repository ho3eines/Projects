-- =============================================
-- webapi/Data/Scripts/store/_Seed.sql
-- Schema: store
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[Customers])
BEGIN
    INSERT INTO [store].[Customers] (CustomerCode, FullName, Phone, Email, IsActive, CreatedAt)
    VALUES
        (N'CST-001', N'سارا رضایی', N'09121234567', N'sara@example.ir', 1, SYSUTDATETIME()),
        (N'CST-002', N'حسین نوری',  N'09351112233', N'hossein@example.ir', 1, SYSUTDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [store].[Products])
BEGIN
    INSERT INTO [store].[Products] (ProductCode, Title, ItemCode, Price, IsActive, CreatedAt)
    VALUES
        (N'P-GOLD24', N'سکه طلا (امامی) — ۱ عدد', N'SIKKEH', 62000000, 1, SYSUTDATETIME()),
        (N'P-GOLD18', N'طلای ۱۸ عیار — ۱ گرم',    N'GOLD-18', 28000000, 1, SYSUTDATETIME()),
        (N'P-CHAIN',  N'زنجیر طلا طرح دار',        N'CHAIN-01', 45000000, 1, SYSUTDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [store].[Orders])
BEGIN
    INSERT INTO [store].[Orders] (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount, TotalAmount, CurrencyCode, Status, CreatedAt)
    VALUES (N'ORD-00001', 1, N'سارا رضایی', CAST(SYSDATETIME() AS DATE), 1, 62000000, N'IRR', N'Placed', SYSUTDATETIME());

    INSERT INTO [store].[OrderItems] (OrderId, ProductId, ProductTitle, Qty, UnitPrice)
    SELECT (SELECT TOP 1 OrderId FROM [store].[Orders] ORDER BY OrderId DESC), ProductId, Title, 1, Price
    FROM [store].[Products] WHERE ProductCode = N'P-GOLD24';
END

-- Cart sample so the "ثبت سفارش" flow has something to place.
IF NOT EXISTS (SELECT 1 FROM [store].[CartItems])
BEGIN
    INSERT INTO [store].[CartItems] (CustomerId, ProductId, Qty, AddedAt)
    VALUES (2, 2, 2, SYSUTDATETIME());
END
