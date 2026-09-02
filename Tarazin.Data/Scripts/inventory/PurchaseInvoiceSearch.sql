-- =============================================
-- Tarazin.Data/Scripts/inventory/PurchaseInvoiceSearch.sql
-- Schema: inventory
-- Query. جستجوی فاکتورهای خرید (جدول یکپارچه Invoices با OperationType=Purchase).
-- =============================================
SELECT i.InvoiceId AS PurchaseInvoiceId, i.InvoiceNumber, i.InvoiceDate,
       i.SupplierPartyId, i.SupplierName,
       i.WarehouseId, w.Title AS WarehouseTitle,
       i.ReferenceNumber, i.PaymentTerms, i.DueDate,
       i.GrossAmount, i.DiscountAmount, i.TaxAmount, i.DutyAmount, i.NetAmount,
       i.Status, i.DocumentId, i.CreatedAt, i.CreatedBy
FROM [inventory].[Invoices] i
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = i.WarehouseId AND w.IsDeleted = 0
WHERE i.IsDeleted = 0 AND i.CompanyId = @CompanyId AND i.OperationType = N'Purchase'
  AND (@FromDate IS NULL OR i.InvoiceDate >= @FromDate)
  AND (@ToDate IS NULL OR i.InvoiceDate <= @ToDate)
  AND (@Status IS NULL OR @Status = N'' OR i.Status = @Status)
  AND (@SupplierPartyId IS NULL OR i.SupplierPartyId = @SupplierPartyId)
  AND (@WarehouseId IS NULL OR @WarehouseId = 0 OR i.WarehouseId = @WarehouseId)
  AND (@Search IS NULL OR @Search = N''
       OR i.InvoiceNumber LIKE N'%' + @Search + N'%'
       OR i.SupplierName LIKE N'%' + @Search + N'%'
       OR i.ReferenceNumber LIKE N'%' + @Search + N'%')
ORDER BY i.InvoiceDate DESC, i.InvoiceId DESC;
