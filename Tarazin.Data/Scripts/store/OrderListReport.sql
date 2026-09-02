-- =============================================
-- Tarazin.Data/Scripts/store/OrderListReport.sql
-- Schema: store
-- Query. گزارش سفارش‌ها در بازه (یک ردیف به ازای هر سفارش).
-- =============================================
SELECT
    o.OrderId,
    o.OrderNumber,
    o.OrderDate,
    o.CustomerName,
    o.ItemCount,
    o.TotalAmount,
    o.CurrencyCode,
    o.Status,
    o.PaymentStatus,
    o.BalanceRial,
    o.PayCash,
    o.PayBank,
    o.ChequeNumber,
    o.ChequeBankId,
    o.ChequeAmount,
    o.ChequeDueDate,
    o.DocumentId,
    o.StoreId,
    s.Title AS StoreTitle,
    o.CreatedAt,
    o.UpdatedAt,
    o.CreatedBy,
    o.UpdatedBy
FROM [store].[Orders] o
LEFT JOIN [store].[Stores] s ON s.StoreId = o.StoreId
WHERE o.CompanyId = @CompanyId
  AND o.OrderDate BETWEEN @FromDate AND @ToDate
  AND (@Status IS NULL OR o.Status = @Status)
  AND (@StoreId IS NULL OR o.StoreId = @StoreId)
ORDER BY o.OrderDate DESC, o.OrderId DESC;
