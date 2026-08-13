-- =============================================
-- Tarazin.Data/Scripts/store/OrderSearch.sql
-- Schema: store | Contract: Order / Cart
-- Query. Shape MUST match OrderRow (Share) exactly.
-- =============================================
SELECT
    o.OrderId,
    o.OrderNumber,
    o.CustomerId,
    o.CustomerName,
    o.ItemCount,
    o.TotalAmount,
    o.CurrencyCode,
    o.Status,
    o.OrderDate,
    o.CreatedAt,
    o.UpdatedAt,
    o.CreatedBy,
    o.UpdatedBy
FROM [store].[Orders] o
ORDER BY o.OrderId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
