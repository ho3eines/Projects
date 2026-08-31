-- =============================================
-- Tarazin.Data/Scripts/inventory/SalesInvoiceSearch.sql
-- Schema: inventory
-- Query. جستجوی فاکتورهای فروش (جدول یکپارچه Invoices با OperationType=Sales).
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
  AND (@Search IS NULL OR @Search = N''
       OR i.InvoiceNumber LIKE N'%' + @Search + N'%'
       OR i.CustomerName LIKE N'%' + @Search + N'%'
       OR i.ReferenceNumber LIKE N'%' + @Search + N'%')
ORDER BY i.InvoiceDate DESC, i.InvoiceId DESC;
