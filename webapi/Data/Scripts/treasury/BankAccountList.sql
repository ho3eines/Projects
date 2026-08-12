-- =============================================
-- webapi/Data/Scripts/treasury/BankAccountList.sql
-- Schema: treasury
-- Query.
-- =============================================
SELECT a.AccountId, a.AccountName, a.AccountNo, b.Title AS BankName, a.Balance
FROM [treasury].[BankAccounts] a
LEFT JOIN [treasury].[Banks] b ON b.BankId = a.BankId
WHERE a.IsDeleted = 0
ORDER BY a.AccountName;
