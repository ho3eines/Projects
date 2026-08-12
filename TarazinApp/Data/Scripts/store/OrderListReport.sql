-- =============================================
-- TarazinApp/Data/Scripts/store/OrderListReport.sql
-- Schema: store
-- Query. گزارش سفارش‌ها در بازه (با اقلام).
-- =============================================
SELECT
    o.OrderNumber,
    o.OrderDate,
    o.CustomerName,
    oi.ProductTitle,
    oi.Qty,
    oi.UnitPrice,
    o.Status,
    o.TotalAmount
FROM [store].[Orders] o
JOIN [store].[OrderItems] oi ON oi.OrderId = o.OrderId
WHERE o.OrderDate BETWEEN @FromDate AND @ToDate
  AND (@Status IS NULL OR o.Status = @Status)
ORDER BY o.OrderDate, o.OrderId, oi.OrderItemId;
