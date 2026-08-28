-- =============================================
-- Tarazin.Data/Scripts/treasury/BankAccountList.sql
-- Schema: treasury
-- Query. فهرست حساب‌های بانکی شرکت فعال.
-- =============================================
SELECT a.AccountId, a.AccountName, a.AccountNo, b.Title AS BankName, a.Balance,
       a.BankId, a.IsActive, a.CreatedAt, a.UpdatedAt
FROM [treasury].[BankAccounts] a
LEFT JOIN [treasury].[Banks] b ON b.BankId = a.BankId
WHERE a.IsDeleted = 0
  AND (@CompanyId IS NULL OR a.CompanyId = @CompanyId)
ORDER BY a.AccountName;
