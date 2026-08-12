-- =============================================
-- Tarazin.Shared/Data/Scripts/accounting/ChartOfAccountSearch.sql
-- Schema: accounting | Contract: ChartOfAccount
-- Query. Shape MUST match ChartOfAccountRow (Share) exactly.
-- =============================================
SELECT
    c.AccountId,
    c.AccountCode,
    c.Title,
    c.AccountType,
    c.ParentAccountId,
    c.IsActive
FROM [accounting].[ChartOfAccounts] c
WHERE c.IsDeleted = 0
  AND (@SearchText = N'' OR c.Title LIKE N'%' + @SearchText + N'%'
       OR c.AccountCode LIKE N'%' + @SearchText + N'%')
ORDER BY c.AccountCode
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
