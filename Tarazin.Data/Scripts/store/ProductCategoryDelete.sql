-- =============================================
-- Tarazin.Data/Scripts/store/ProductCategoryDelete.sql
-- Schema: store
-- Execute.
-- =============================================
-- Soft-delete a category (IsDeleted=1) while preserving references.
UPDATE [store].[ProductCategories]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
WHERE CategoryId = @CategoryId AND IsDeleted = 0;
