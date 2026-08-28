-- =============================================
-- Tarazin.Data/Scripts/treasury/BankList.sql
-- Schema: treasury
-- Query. فهرست بانک‌های شرکت فعال.
-- =============================================
SELECT b.BankId, b.BankCode, b.Title, b.IsActive, b.CreatedAt, b.UpdatedAt
FROM [treasury].[Banks] b
WHERE b.IsDeleted = 0
  AND (@CompanyId IS NULL OR b.CompanyId = @CompanyId)
ORDER BY b.Title;
