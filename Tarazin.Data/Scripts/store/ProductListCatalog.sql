-- =============================================
-- Tarazin.Data/Scripts/store/ProductListCatalog.sql
-- Schema: store | Cross-schema: inventory
-- Query. فهرست کاتالوگ با دسته/برند/موجودی قابل فروش (server-side paging).
--   Available = StockQty - رزرو فعال (منبع حقیقت: انبار متصل به محصول/فروشگاه)
-- =============================================
SELECT
    p.ProductId, p.ProductCode, p.SKU, p.Barcode, p.Title,
    p.CategoryId, c.Title AS CategoryTitle,
    p.BrandId, b.Title AS BrandTitle,
    p.ItemCode, p.Price, p.DiscountPrice,
    p.MainImageUrl, p.IsActive, p.HasVariants,
    ISNULL(it.StockQty, 0)
      - ISNULL((SELECT SUM(r.Qty) FROM [inventory].[Reservations] r
                WHERE r.ItemCode = p.ItemCode AND r.Status = N'Active'), 0) AS AvailableQty,
    (SELECT COUNT(*) FROM [store].[ProductVariants] v
     WHERE v.ProductId = p.ProductId AND v.IsDeleted = 0) AS VariantCount
FROM [store].[Products] p
LEFT JOIN [store].[ProductCategories] c ON c.CategoryId = p.CategoryId
LEFT JOIN [store].[Brands] b ON b.BrandId = p.BrandId
LEFT JOIN [inventory].[Items] it ON it.ItemCode = p.ItemCode
WHERE p.CompanyId = @CompanyId
  AND p.IsDeleted = 0
  AND (@SearchText = N'' OR p.Title LIKE N'%' + @SearchText + N'%'
       OR p.ProductCode LIKE N'%' + @SearchText + N'%'
       OR p.SKU LIKE N'%' + @SearchText + N'%'
       OR p.Barcode LIKE N'%' + @SearchText + N'%')
  AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
  AND (@BrandId IS NULL OR p.BrandId = @BrandId)
  AND (@InStockOnly IS NULL OR @InStockOnly = 0
       OR ISNULL(it.StockQty, 0)
          - ISNULL((SELECT SUM(r.Qty) FROM [inventory].[Reservations] r
                    WHERE r.ItemCode = p.ItemCode AND r.Status = N'Active'), 0) > 0)
ORDER BY p.Title
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;

SELECT COUNT(*) AS TotalCount
FROM [store].[Products] p
LEFT JOIN [inventory].[Items] it ON it.ItemCode = p.ItemCode
WHERE p.CompanyId = @CompanyId
  AND p.IsDeleted = 0
  AND (@SearchText = N'' OR p.Title LIKE N'%' + @SearchText + N'%'
       OR p.ProductCode LIKE N'%' + @SearchText + N'%'
       OR p.SKU LIKE N'%' + @SearchText + N'%'
       OR p.Barcode LIKE N'%' + @SearchText + N'%')
  AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
  AND (@BrandId IS NULL OR p.BrandId = @BrandId)
  AND (@InStockOnly IS NULL OR @InStockOnly = 0
       OR ISNULL(it.StockQty, 0)
          - ISNULL((SELECT SUM(r.Qty) FROM [inventory].[Reservations] r
                    WHERE r.ItemCode = p.ItemCode AND r.Status = N'Active'), 0) > 0);
