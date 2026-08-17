-- =============================================
-- Tarazin.Data/Scripts/central/CompanyDelete.sql
-- Schema: central
-- Execute. Soft delete a company.
-- =============================================
UPDATE [central].[Companies]
SET IsDeleted = 1,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy
WHERE CompanyId = @CompanyId;
