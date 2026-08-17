-- =============================================
-- Tarazin.Data/Scripts/central/FiscalYearDelete.sql
-- Schema: central
-- Execute. Soft delete a fiscal year.
-- =============================================
UPDATE [central].[FiscalYears]
SET IsDeleted = 1,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy
WHERE FiscalYearId = @FiscalYearId;
