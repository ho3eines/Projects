-- =============================================
-- Tarazin.Data/Scripts/store/CouponList.sql
-- Schema: store
-- Query. فهرست کدهای تخفیف با آمار مصرف.
-- =============================================
SELECT
    c.CouponId,
    c.CompanyId,
    c.Code,
    c.Title,
    c.StoreId,
    s.Title AS StoreTitle,
    c.DiscountType,
    c.DiscountValue,
    c.MaxDiscount,
    c.MinOrderTotal,
    c.UsageLimit,
    c.UsedCount,
    c.PerCustomerLimit,
    c.FromDate,
    c.ToDate,
    c.IsActive,
    CASE WHEN GETDATE() BETWEEN c.FromDate AND c.ToDate
          AND c.IsActive = 1
          AND (c.UsageLimit IS NULL OR c.UsedCount < c.UsageLimit)
         THEN 1 ELSE 0 END AS IsValidNow
FROM [store].[Coupons] c
LEFT JOIN [store].[Stores] s ON s.StoreId = c.StoreId
WHERE c.CompanyId = @CompanyId
  AND c.IsDeleted = 0
  AND (@CouponId IS NULL OR c.CouponId = @CouponId)
  AND (@StoreId IS NULL OR c.StoreId = @StoreId OR c.StoreId IS NULL)
ORDER BY c.Code;
