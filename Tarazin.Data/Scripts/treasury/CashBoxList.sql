-- =============================================
-- Tarazin.Data/Scripts/treasury/CashBoxList.sql
-- Schema: treasury
-- Query.
-- =============================================
SELECT c.CashBoxId, c.CashBoxCode, c.Title, c.Balance
FROM [treasury].[CashBoxes] c
WHERE c.IsDeleted = 0
ORDER BY c.Title;
