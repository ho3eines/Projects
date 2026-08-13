-- =============================================
-- Tarazin.Data/Scripts/currency/FundList.sql
-- Schema: currency
-- Cross-schema: treasury (صندوق‌ها و حساب‌های بانکی)
-- Query. فهرست محل‌های تسویه برای معاملات ارز (صندوق/بانک).
-- =============================================
SELECT N'Cash' AS FundType, c.CashBoxId AS FundId, c.Title AS FundTitle
FROM [treasury].[CashBoxes] c
WHERE c.IsActive = 1 AND c.IsDeleted = 0

UNION ALL

SELECT N'Bank', b.AccountId, b.AccountName
FROM [treasury].[BankAccounts] b
WHERE b.IsActive = 1 AND b.IsDeleted = 0

ORDER BY FundType, FundTitle;
