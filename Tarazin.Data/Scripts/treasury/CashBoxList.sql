-- =============================================
-- Tarazin.Data/Scripts/treasury/CashBoxList.sql
-- Schema: treasury
-- Query. فهرست صندوق‌های شرکت فعال.
-- =============================================
SELECT c.CashBoxId, c.CashBoxCode, c.Title, c.Balance, c.IsActive, c.CreatedAt, c.UpdatedAt
FROM [treasury].[CashBoxes] c
WHERE c.IsDeleted = 0
  AND (@CompanyId IS NULL OR c.CompanyId = @CompanyId)
ORDER BY c.Title;
