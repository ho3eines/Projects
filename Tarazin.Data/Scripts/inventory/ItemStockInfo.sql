-- =============================================
-- Tarazan.Data/Scripts/inventory/ItemStockInfo.sql
-- Schema: inventory
-- Query. موجودی لحظه‌ای + قیمت آخرین خرید برای یک کالا (استفاده در
-- دیالوگ اتصال جنس طلا به کالای انبار و هر نمایش سریع کالا).
-- پارامتر: @ItemId
-- =============================================
SELECT
    i.StockQty,
    i.Unit,
    (SELECT TOP 1 il.UnitPrice
     FROM [inventory].[InvoiceLines] il
     JOIN [inventory].[Invoices] inv ON inv.InvoiceId = il.InvoiceId
     WHERE il.ItemId = @ItemId
       AND inv.OperationType = N'Purchase'
       AND inv.IsDeleted = 0
     ORDER BY inv.InvoiceDate DESC, inv.InvoiceId DESC) AS LastPurchasePrice,
    (SELECT TOP 1 il.UnitPrice
     FROM [inventory].[InvoiceLines] il
     JOIN [inventory].[Invoices] inv ON inv.InvoiceId = il.InvoiceId
     WHERE il.ItemId = @ItemId
       AND inv.OperationType = N'Sales'
       AND inv.IsDeleted = 0
     ORDER BY inv.InvoiceDate DESC, inv.InvoiceId DESC) AS LastSalePrice
FROM [inventory].[Items] i
WHERE i.ItemId = @ItemId;