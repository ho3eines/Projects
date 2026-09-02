-- =============================================
-- Tarazin.Data/Scripts/store/PriceListDelete.sql
-- Schema: store
-- Execute. حذف نرم لیست قیمت + قیمت‌های وابسته.
-- =============================================
UPDATE [store].[ProductPrices] SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
 WHERE PriceListId = @PriceListId AND CompanyId = @CompanyId AND IsDeleted = 0;

UPDATE [store].[PriceLists] SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
 WHERE PriceListId = @PriceListId AND CompanyId = @CompanyId AND IsDeleted = 0;
