-- =============================================
-- Tarazin.Data/Scripts/treasury/CashBoxDelete.sql
-- Schema: treasury
-- Execute. حذف نرم صندوق.
-- =============================================
UPDATE [treasury].[CashBoxes]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
WHERE CashBoxId = @CashBoxId AND CompanyId = @CompanyId AND IsDeleted = 0;
