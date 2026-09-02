-- =============================================
-- Tarazin.Data/Scripts/store/BrandDelete.sql
-- Schema: store
-- Execute. حذف منطقی برند. اگر محصولی متصل داشته باشد → 51343.
-- =============================================
IF EXISTS (SELECT 1 FROM [store].[Products] WHERE BrandId = @BrandId AND IsDeleted = 0)
    THROW 51343, N'این برند به محصول متصل است و قابل حذف نیست', 1;

UPDATE [store].[Brands]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE BrandId = @BrandId AND CompanyId = @CompanyId;
