-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldInvoiceLines.sql
-- Schema: goldshop
-- Execute. لود ردیف‌های یک فاکتور برای ویرایش.
-- =============================================
SELECT
    l.LineId,
    l.RowType,
    l.ItemCode,
    l.Title,
    l.Qty,
    l.Price,
    l.Rate,
    l.Workmanship,
    l.Profit,
    l.TaxEnabled,
    l.LineBase,
    l.LineTax,
    l.LineTotal
FROM [goldshop].[InvoiceLines] l
WHERE l.InvoiceId=@InvoiceId AND l.CompanyId=@CompanyId
ORDER BY l.LineId;