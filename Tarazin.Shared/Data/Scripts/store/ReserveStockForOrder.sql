-- =============================================
-- Tarazin.Shared/Data/Scripts/store/ReserveStockForOrder.sql
-- Schema: store | Consumer of OrderPlaced
-- Cross-schema: inventory
-- Execute. Saga step 1: رزرو موجودی → StockReserved / StockRejected.
-- Idempotent on OrderReservations.OrderId.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[OrderReservations] WHERE OrderId = @OrderId)
BEGIN
    BEGIN TRY
        BEGIN TRAN;
            DECLARE @Unavailable INT = 0;

            -- Any line without enough free stock, or without a stock item?
            SELECT @Unavailable = COUNT(*)
            FROM [store].[OrderItems] oi
            LEFT JOIN [store].[Products] p ON p.ProductId = oi.ProductId
            LEFT JOIN [inventory].[Items] it ON it.ItemCode = p.ItemCode
            WHERE oi.OrderId = @OrderId
              AND (p.ItemCode IS NULL OR it.ItemCode IS NULL
                   OR it.StockQty < oi.Qty + ISNULL((
                        SELECT SUM(r.Qty) FROM [inventory].[Reservations] r
                        WHERE r.ItemCode = p.ItemCode AND r.Status = N'Active' AND r.OrderId <> @OrderId), 0));

            IF @Unavailable > 0
            BEGIN
                UPDATE [store].[Orders] SET Status = N'Rejected' WHERE OrderId = @OrderId;

                INSERT INTO [store].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
                VALUES (N'StockRejected', CONCAT(N'OrderId=', @OrderId),
                    (SELECT @OrderId AS OrderId FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
            END
            ELSE
            BEGIN
                INSERT INTO [inventory].[Reservations] (ItemCode, Qty, OrderId, Status, CreatedAt)
                SELECT p.ItemCode, oi.Qty, @OrderId, N'Active', SYSUTCDATETIME()
                FROM [store].[OrderItems] oi
                JOIN [store].[Products] p ON p.ProductId = oi.ProductId
                WHERE oi.OrderId = @OrderId;

                INSERT INTO [store].[OrderReservations] (OrderId, ReservedAt) VALUES (@OrderId, SYSUTCDATETIME());

                UPDATE [store].[Orders] SET Status = N'Reserved' WHERE OrderId = @OrderId;

                DECLARE @CustomerName NVARCHAR(200) = (SELECT CustomerName FROM [store].[Orders] WHERE OrderId = @OrderId);
                DECLARE @Total DECIMAL(18,2) = (SELECT TotalAmount FROM [store].[Orders] WHERE OrderId = @OrderId);
                DECLARE @Currency NVARCHAR(10) = (SELECT CurrencyCode FROM [store].[Orders] WHERE OrderId = @OrderId);

                INSERT INTO [store].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
                VALUES (N'StockReserved', CONCAT(N'OrderId=', @OrderId),
                    (SELECT @OrderId AS OrderId, @CustomerName AS CustomerName,
                            @Total AS TotalAmount, @Currency AS CurrencyCode
                     FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
            END
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
