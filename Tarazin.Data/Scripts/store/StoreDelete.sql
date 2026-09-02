-- =============================================
-- Tarazin.Data/Scripts/store/StoreDelete.sql
-- Schema: store
-- Execute. حذف منطقی فروشگاه. اگر سفارش/مشتری/کالایی متصل داشته باشد → 51310.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [store].[Stores] WHERE StoreId = @StoreId AND CompanyId = @CompanyId AND IsDeleted = 0)
    THROW 51303, N'فروشگاه یافت نشد یا حذف شده است', 1;

IF EXISTS (SELECT 1 FROM [store].[Orders]   WHERE StoreId = @StoreId)
   OR EXISTS (SELECT 1 FROM [store].[Customers] WHERE StoreId = @StoreId AND IsDeleted = 0)
   OR EXISTS (SELECT 1 FROM [store].[Products]  WHERE StoreId = @StoreId AND IsDeleted = 0)
    THROW 51310, N'این فروشگاه سفارش/مشتری/کالای متصل دارد و قابل حذف نیست؛ آن را غیرفعال کنید', 1;

UPDATE [store].[Stores]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
WHERE StoreId = @StoreId AND CompanyId = @CompanyId;
