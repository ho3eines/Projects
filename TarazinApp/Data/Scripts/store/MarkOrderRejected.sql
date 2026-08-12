-- =============================================
-- TarazinApp/Data/Scripts/store/MarkOrderRejected.sql
-- Schema: store | Consumer of StockRejected
-- Execute. Idempotent safeguard (status usually set by ReserveStockForOrder).
-- =============================================
IF EXISTS (SELECT 1 FROM [store].[Orders] WHERE OrderId = @OrderId AND Status = N'Placed')
    UPDATE [store].[Orders] SET Status = N'Rejected' WHERE OrderId = @OrderId;
