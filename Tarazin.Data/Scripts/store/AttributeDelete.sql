-- =============================================
-- Tarazin.Data/Scripts/store/AttributeDelete.sql
-- Schema: store
-- Execute. حذف منطقی ویژگی. اگر در محصول/تنوع استفاده شده → 51353.
-- =============================================
IF EXISTS (SELECT 1 FROM [store].[ProductAttributes] WHERE AttributeId = @AttributeId)
   OR EXISTS (SELECT 1 FROM [store].[VariantAttributes] WHERE AttributeId = @AttributeId)
    THROW 51353, N'این ویژگی در محصولات استفاده شده و قابل حذف نیست؛ آن را غیرفعال کنید', 1;

UPDATE [store].[Attributes]
SET IsDeleted = 1, IsActive = 0
WHERE AttributeId = @AttributeId AND CompanyId = @CompanyId;
