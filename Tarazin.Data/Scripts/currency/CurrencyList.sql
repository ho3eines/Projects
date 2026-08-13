-- =============================================
-- Tarazin.Data/Scripts/currency/CurrencyList.sql
-- Schema: currency
-- Query. فهرست ارزهای تعریف‌شده (PRD §34/§35).
-- =============================================
SELECT c.CurrencyId, c.CurrencyCode, c.CurrencyName, c.Symbol,
       c.IsBase, c.UnitFactor, c.IsActive, c.IsDeleted,
       c.CreatedAt, c.UpdatedAt, c.CreatedBy, c.UpdatedBy
FROM [currency].[Currencies] c
WHERE c.IsDeleted = 0
  AND (@OnlyActive = 0 OR c.IsActive = 1)
ORDER BY c.IsBase DESC, c.CurrencyCode;
