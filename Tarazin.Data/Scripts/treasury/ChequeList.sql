-- =============================================
-- Tarazin.Data/Scripts/treasury/ChequeList.sql
-- Schema: treasury
-- Query. فهرست چک‌ها با نام بانک و اطلاعات چرخهٔ وصول/برگشت.
-- =============================================
SELECT c.ChequeId, c.ChequeNumber, b.Title AS BankName, c.Amount, c.DueDate,
       c.Direction, c.Status, c.CollectedAt, c.ReturnedAt, c.ReturnReason, c.SourceReference,
       c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
FROM [treasury].[Cheques] c
LEFT JOIN [treasury].[Banks] b ON b.BankId = c.BankId
WHERE c.CompanyId = @CompanyId
  AND (@Direction IS NULL OR c.Direction = @Direction)
  AND (@Status IS NULL OR c.Status = @Status)
ORDER BY c.CreatedAt DESC, c.ChequeId DESC;
