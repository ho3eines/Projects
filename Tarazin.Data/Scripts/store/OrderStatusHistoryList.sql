-- =============================================
-- Tarazin.Data/Scripts/store/OrderStatusHistoryList.sql
-- Schema: store
-- Query. تاریخچهٔ وضعیت‌های یک سفارش.
-- =============================================
SELECT
    h.HistoryId,
    h.OrderId,
    h.FromStatus,
    h.ToStatus,
    h.Reason,
    h.ChangedBy,
    h.CreatedAt
FROM [store].[OrderStatusHistory] h
WHERE h.OrderId = @OrderId
ORDER BY h.HistoryId;
