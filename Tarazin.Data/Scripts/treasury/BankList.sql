-- =============================================
-- Tarazin.Data/Scripts/treasury/BankList.sql
-- Schema: treasury
-- Query.
-- =============================================
SELECT b.BankId, b.BankCode, b.Title, b.IsActive, b.CreatedAt, b.UpdatedAt
FROM [treasury].[Banks] b
WHERE b.IsDeleted = 0
ORDER BY b.Title;
