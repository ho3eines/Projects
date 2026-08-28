-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentSearchByRef.sql
-- Schema: accounting
-- Find accounting document(s) linked to a goldshop invoice.
-- Gold invoices create Documents with DocumentType='Sale' and CounterPartyName=CustomerName.
-- We also search DocumentLines.Description for the invoice number.
-- =============================================
SELECT DISTINCT
    d.DocumentId,
    d.DocumentNumber,
    d.DocumentDate,
    d.DocumentType,
    d.CounterPartyName,
    d.TotalAmount,
    d.Status
FROM [accounting].[Documents] d
INNER JOIN [accounting].[DocumentLines] l ON l.DocumentId = d.DocumentId
WHERE d.IsDeleted = 0
  AND d.CompanyId = @CompanyId
  AND d.FiscalYearId = @FiscalYearId
  AND l.Description LIKE N'%' + @Reference + N'%'
ORDER BY d.DocumentDate DESC, d.DocumentId DESC;
