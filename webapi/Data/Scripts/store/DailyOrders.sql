-- =============================================
-- webapi/Data/Scripts/store/DailyOrders.sql
-- Schema: store
-- Query. Main page grid (سفارش‌های روز).
-- =============================================
SELECT
    o.OrderId,
    o.OrderNumber,
    o.OrderDate,
    o.CustomerName,
    o.ItemCount,
    o.TotalAmount,
    o.CurrencyCode,
    o.Status
FROM [store].[Orders] o
WHERE o.OrderDate BETWEEN @FromDate AND @ToDate
  AND (@SearchText = N'' OR o.OrderNumber LIKE N'%' + @SearchText + N'%'
       OR o.CustomerName LIKE N'%' + @SearchText + N'%')
  AND (@Status IS NULL OR o.Status = @Status)
ORDER BY o.OrderDate DESC, o.OrderId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
