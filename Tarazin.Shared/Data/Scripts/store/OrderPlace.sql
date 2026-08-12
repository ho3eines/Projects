-- =============================================
-- Tarazin.Shared/Data/Scripts/store/OrderPlace.sql
-- Schema: store | Contract: Order (producer)
-- Execute. سفارش از سبد → رویداد OrderPlaced (Command → Event, ADR-002).
-- =============================================
DECLARE @CustomerName NVARCHAR(200);
DECLARE @ItemCount INT;
DECLARE @Total DECIMAL(18,2);

SELECT @CustomerName = cu.FullName
FROM [store].[Customers] cu
WHERE cu.CustomerId = @CustomerId;

IF @CustomerName IS NULL
    THROW 51030, N'مشتری یافت نشد', 1;

SELECT @ItemCount = COUNT(*), @Total = ISNULL(SUM(ci.Qty * p.Price), 0)
FROM [store].[CartItems] ci
JOIN [store].[Products] p ON p.ProductId = ci.ProductId
WHERE ci.CustomerId = @CustomerId;

IF @ItemCount = 0
    THROW 51031, N'سبد خرید خالی است', 1;

BEGIN TRAN;
    INSERT INTO [store].[Orders]
        (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount, TotalAmount, CurrencyCode, Status, CreatedAt)
    VALUES
        (N'', @CustomerId, @CustomerName, CAST(SYSDATETIME() AS DATE), @ItemCount, @Total, N'IRR', N'Placed', SYSUTCDATETIME());

    DECLARE @Oid INT = SCOPE_IDENTITY();
    UPDATE [store].[Orders]
    SET OrderNumber = N'ORD-' + RIGHT(N'00000' + CAST(@Oid AS NVARCHAR(10)), 5)
    WHERE OrderId = @Oid;

    INSERT INTO [store].[OrderItems] (OrderId, ProductId, ProductTitle, Qty, UnitPrice)
    SELECT @Oid, ci.ProductId, p.Title, ci.Qty, p.Price
    FROM [store].[CartItems] ci
    JOIN [store].[Products] p ON p.ProductId = ci.ProductId
    WHERE ci.CustomerId = @CustomerId;

    DELETE FROM [store].[CartItems] WHERE CustomerId = @CustomerId;

    INSERT INTO [store].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'OrderPlaced', CONCAT(N'OrderId=', @Oid),
        (SELECT @Oid AS OrderId, @CustomerId AS CustomerId, @CustomerName AS CustomerName,
                @Total AS TotalAmount, N'IRR' AS CurrencyCode
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
COMMIT;
