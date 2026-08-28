-- =============================================
-- Tarazin.Data/Scripts/store/OrderItemsByOrder.sql
-- Schema: store
-- Query. اقلام یک سفارش.
-- =============================================
SELECT
    oi.OrderItemId,
    oi.OrderId,
    oi.ProductId,
    oi.ProductTitle,
    oi.Qty,
    oi.UnitPrice
FROM [store].[OrderItems] oi
WHERE oi.OrderId = @OrderId
ORDER BY oi.OrderItemId;
