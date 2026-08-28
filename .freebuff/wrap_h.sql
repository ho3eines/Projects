DECLARE @InvoiceId INT=22; DECLARE @CompanyId INT=3;
-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldInvoiceHeader.sql
-- Schema: goldshop
-- Execute. لود سرصفحه یک فاکتور برای ویرایش.
-- =============================================
SELECT
    s.InvoiceId,
    s.InvoiceNumber,
    s.InvoiceDate,
    s.PartyId,
    s.CustomerName AS PartyName,
    s.Status,
    s.TotalAmount,
    s.PaymentStatus,
    IIF(s.InvoiceNumber LIKE N'GPUR-%', N'Purchase', N'Sale') AS InvoiceType
FROM [goldshop].[SaleInvoices] s
WHERE s.InvoiceId=@InvoiceId AND s.CompanyId=@CompanyId;