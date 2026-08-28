-- =============================================
-- Tarazin.Data/Scripts/treasury/BankAccountDelete.sql
-- Schema: treasury
-- Execute. حذف نرم حساب بانکی.
-- =============================================
UPDATE [treasury].[BankAccounts]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
WHERE AccountId = @AccountId AND CompanyId = @CompanyId AND IsDeleted = 0;
