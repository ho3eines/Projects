-- =============================================
-- Tarazin.Data/Scripts/branch/BranchDelete.sql
-- Schema: branch
-- Execute. حذف منطقی شعبه.
-- =============================================
UPDATE [branch].[Branches]
SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE BranchId = @BranchId;
