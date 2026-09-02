-- =============================================
-- Tarazin.Data/Scripts/store/PromotionList.sql
-- Schema: store
-- Query. فهرست کمپین‌های تخفیف با نام دامنه (فروشگاه/محصول/دسته).
-- =============================================
SELECT
    pr.PromotionId,
    pr.CompanyId,
    pr.Code,
    pr.Title,
    pr.StoreId,
    s.Title AS StoreTitle,
    pr.ProductId,
    p.Title AS ProductTitle,
    pr.CategoryId,
    pc.Title AS CategoryTitle,
    pr.DiscountType,
    pr.DiscountValue,
    pr.FromDate,
    pr.ToDate,
    pr.MinOrderTotal,
    pr.IsActive,
    CASE WHEN GETDATE() BETWEEN pr.FromDate AND pr.ToDate AND pr.IsActive = 1 THEN 1 ELSE 0 END AS IsRunning
FROM [store].[Promotions] pr
LEFT JOIN [store].[Stores] s             ON s.StoreId = pr.StoreId
LEFT JOIN [store].[Products] p           ON p.ProductId = pr.ProductId
LEFT JOIN [store].[ProductCategories] pc ON pc.CategoryId = pr.CategoryId
WHERE pr.CompanyId = @CompanyId
  AND pr.IsDeleted = 0
  AND (@PromotionId IS NULL OR pr.PromotionId = @PromotionId)
  AND (@StoreId IS NULL OR pr.StoreId = @StoreId OR pr.StoreId IS NULL)
ORDER BY pr.FromDate DESC;
