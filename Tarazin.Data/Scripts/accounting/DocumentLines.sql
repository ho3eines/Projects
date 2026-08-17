-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentLines.sql
-- Schema: accounting
-- ردیف‌های (بدهکار/بستانکار) یک سند حسابداری.
-- ایندکس IX_DocumentLines_Document این جستجو را O(log n) می‌کند.
-- =============================================
SELECT
    l.DocumentLineId,
    l.DocumentId,
    l.AccountId,
    l.AccountCode,
    l.Title,
    l.[Description],
    l.Debit,
    l.Credit
FROM [accounting].[DocumentLines] l
INNER JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId
WHERE l.DocumentId = @DocumentId
ORDER BY l.DocumentLineId;
