-- =============================================
-- Tarazin.Data/Scripts/store/CouponDelete.sql
-- Schema: store
-- Execute. حذف نرم کد تخفیف.
-- =============================================
UPDATE [store].[Coupons] SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
 WHERE CouponId = @CouponId AND CompanyId = @CompanyId AND IsDeleted = 0;
