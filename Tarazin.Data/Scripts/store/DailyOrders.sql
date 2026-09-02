-- =============================================
-- Tarazin.Data/Scripts/store/DailyOrders.sql
-- Schema: store
-- Query. Main page grid (سفارش‌های روز).
-- =============================================
SELECT
    o.OrderId,
    o.OrderNumber,
    o.OrderDate,
    o.CustomerName,
    o.StoreId,
    s.Title AS StoreTitle,
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
    o.CreatedAt,
    o.UpdatedAt,
    o.CreatedBy,
    o.UpdatedBy
FROM [store].[Orders] o
LEFT JOIN [store].[Stores] s ON s.StoreId = o.StoreId
WHERE o.CompanyId = @CompanyId
  AND o.OrderDate BETWEEN @FromDate AND @ToDate
  AND (@SearchText = N'' OR o.OrderNumber LIKE N'%' + @SearchText + N'%'
       OR o.CustomerName LIKE N'%' + @SearchText + N'%')
  AND (@Status IS NULL OR o.Status = @Status)
  AND (@StoreId IS NULL OR o.StoreId = @StoreId)
ORDER BY o.OrderDate DESC, o.OrderId DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
