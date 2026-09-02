-- =============================================
-- Tarazin.Data/Scripts/store/PromotionDelete.sql
-- Schema: store
-- Execute. حذف نرم کمپین.
-- =============================================
UPDATE [store].[Promotions] SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
 WHERE PromotionId = @PromotionId AND CompanyId = @CompanyId AND IsDeleted = 0;
