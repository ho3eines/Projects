-- =============================================
-- Tarazin.Data/Scripts/treasury/BankDelete.sql
-- Schema: treasury
-- Execute. حذف نرم بانک.
-- =============================================
UPDATE [treasury].[Banks]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
WHERE BankId = @BankId AND CompanyId = @CompanyId AND IsDeleted = 0;
