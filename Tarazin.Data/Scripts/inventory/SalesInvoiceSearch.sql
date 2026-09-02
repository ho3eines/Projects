-- =============================================
-- Tarazin.Data/Scripts/inventory/SalesInvoiceSearch.sql
-- Schema: inventory
-- Query. جستجوی فروش‌ها: فاکتورهای فروش انبار (جدول یکپارچه Invoices با OperationType=Sales)
-- + سفارش‌های POS فروشگاه (store.Orders) به‌صورت فقط‌خواندنی — هر دو کانال در یک لیست.
-- ردیف‌های فروشگاه: SalesInvoiceId منفی (synthetic = -OrderId)، Status=N'Store'،
-- انبار/بهای تمام‌شده از حرکات خروج همان سفارش (SourceReference=StoreOrder:id — عقب‌مانده‌ها با Description).
-- =============================================
SELECT i.InvoiceId AS SalesInvoiceId, i.InvoiceNumber, i.InvoiceDate,
       i.CustomerPartyId, i.CustomerName,
       i.WarehouseId, w.Title AS WarehouseTitle,
       i.ReferenceNumber, i.PaymentTerms, i.DueDate, i.SaleType,
       i.GrossAmount, i.DiscountAmount, i.TaxAmount, i.DutyAmount, i.NetAmount,
       i.CostOfGoodsSold, i.GrossProfit,
       i.Status, i.DocumentId, i.CreatedAt, i.CreatedBy
FROM [inventory].[Invoices] i
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = i.WarehouseId AND w.IsDeleted = 0
WHERE i.IsDeleted = 0 AND i.CompanyId = @CompanyId AND i.OperationType = N'Sales'
  AND (@FromDate IS NULL OR i.InvoiceDate >= @FromDate)
  AND (@ToDate IS NULL OR i.InvoiceDate <= @ToDate)
  AND (@Status IS NULL OR @Status = N'' OR i.Status = @Status)
  AND (@CustomerPartyId IS NULL OR i.CustomerPartyId = @CustomerPartyId)
  AND (@WarehouseId IS NULL OR @WarehouseId = 0 OR i.WarehouseId = @WarehouseId)
  AND (@Search IS NULL OR @Search = N''
       OR i.InvoiceNumber LIKE N'%' + @Search + N'%'
       OR i.CustomerName LIKE N'%' + @Search + N'%'
       OR i.ReferenceNumber LIKE N'%' + @Search + N'%')

UNION ALL

-- ── کانال فروشگاه (POS) — فقط‌خواندنی؛ انبار و COGS از حرکات خروج سفارش ──
SELECT -o.OrderId AS SalesInvoiceId, o.OrderNumber AS InvoiceNumber, o.OrderDate AS InvoiceDate,
       cu.PartyId AS CustomerPartyId, o.CustomerName,
       mv.WarehouseId, mv.WarehouseTitle,
       NULL AS ReferenceNumber, NULL AS PaymentTerms, NULL AS DueDate, N'POS' AS SaleType,
       o.GrossTotal AS GrossAmount, o.DiscountTotal AS DiscountAmount,
       0 AS TaxAmount, 0 AS DutyAmount, o.TotalAmount AS NetAmount,
       ISNULL(mv.Cogs, 0) AS CostOfGoodsSold,
       o.TotalAmount - ISNULL(mv.Cogs, 0) AS GrossProfit,
       N'Store' AS Status, o.DocumentId, o.CreatedAt, o.CreatedBy
FROM [store].[Orders] o
JOIN [store].[Customers] cu ON cu.CustomerId = o.CustomerId AND cu.IsDeleted = 0
OUTER APPLY (
    SELECT SUM(m.Qty * m.CostPrice) AS Cogs,
           MAX(m.WarehouseId) AS WarehouseId,
           MAX(w2.Title) AS WarehouseTitle
    FROM [inventory].[Movements] m
    LEFT JOIN [inventory].[Warehouses] w2 ON w2.WarehouseId = m.WarehouseId
    WHERE m.IsDeleted = 0 AND m.CompanyId = @CompanyId AND m.MovementType = N'Issue'
      AND (m.SourceReference = CONCAT(N'StoreOrder:', o.OrderId)
           OR m.Description LIKE N'%' + o.OrderNumber)
) mv
WHERE o.CompanyId = @CompanyId
  AND (@FromDate IS NULL OR o.OrderDate >= @FromDate)
  AND (@ToDate IS NULL OR o.OrderDate <= @ToDate)
  AND (@Status IS NULL OR @Status = N'' OR @Status = N'Store')
  AND (@CustomerPartyId IS NULL OR cu.PartyId = @CustomerPartyId)
  AND (@WarehouseId IS NULL OR @WarehouseId = 0 OR mv.WarehouseId = @WarehouseId)
  AND (@Search IS NULL OR @Search = N''
       OR o.OrderNumber LIKE N'%' + @Search + N'%'
       OR o.CustomerName LIKE N'%' + @Search + N'%')

ORDER BY InvoiceDate DESC, SalesInvoiceId DESC;
