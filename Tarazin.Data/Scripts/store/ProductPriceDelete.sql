-- =============================================
-- Tarazin.Data/Scripts/store/ProductPriceDelete.sql
-- Schema: store
-- Execute. حذف نرم قیمت محصول.
-- =============================================
UPDATE [store].[ProductPrices] SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
 WHERE PriceId = @PriceId AND CompanyId = @CompanyId AND IsDeleted = 0;
