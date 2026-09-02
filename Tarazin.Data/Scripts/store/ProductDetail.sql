-- =============================================
-- Tarazin.Data/Scripts/store/ProductDetail.sql
-- Schema: store | Cross-schema: inventory
-- Query. جزئیات کامل محصول + ویژگی‌ها + تنوع‌ها + تصاویر (سه Result Set).
-- Result 1: محصول | Result 2: ProductAttributes | Result 3: Variants (+facets) | Result 4: Images
-- =============================================
SELECT
    p.ProductId, p.CompanyId, p.ProductCode, p.SKU, p.Barcode, p.Title, p.ShortTitle,
    p.EnglishTitle, p.CategoryId, p.BrandId, p.UnitId, p.ItemCode,
    p.Price, p.OnlinePrice, p.CostPrice, p.DiscountPrice, p.DiscountFrom, p.DiscountTo,
    p.Slug, p.SeoTitle, p.MetaDescription, p.LongDescription,
    p.Weight, p.Dimensions, p.MainImageUrl, p.HasVariants, p.StoreId, p.IsActive
FROM [store].[Products] p
WHERE p.ProductId = @ProductId AND p.CompanyId = @CompanyId AND p.IsDeleted = 0;

SELECT
    pa.ProductAttributeId, pa.AttributeId, a.Title AS AttributeTitle, a.Unit,
    pa.ValueText, pa.SortOrder
FROM [store].[ProductAttributes] pa
JOIN [store].[Attributes] a ON a.AttributeId = pa.AttributeId
WHERE pa.ProductId = @ProductId
ORDER BY pa.SortOrder, pa.ProductAttributeId;

SELECT
    v.VariantId, v.VariantCode, v.Title, v.Barcode, v.Price, v.DiscountPrice,
    v.Weight, v.ImageUrl, v.IsActive, v.ItemCode,
    (SELECT ISNULL(it.StockQty, 0)
     - ISNULL((SELECT SUM(r.Qty) FROM [inventory].[Reservations] r
               WHERE r.ItemCode = v.ItemCode AND r.Status = N'Active'), 0)
     FROM [inventory].[Items] it WHERE it.ItemCode = v.ItemCode) AS AvailableQty,
    (SELECT STRING_AGG(CAST(a.Title AS NVARCHAR(200)) + N': ' + va.ValueText, N' | ')
     FROM [store].[VariantAttributes] va
     JOIN [store].[Attributes] a ON a.AttributeId = va.AttributeId
     WHERE va.VariantId = v.VariantId) AS FacetsSummary
FROM [store].[ProductVariants] v
WHERE v.ProductId = @ProductId AND v.IsDeleted = 0
ORDER BY v.VariantId;

SELECT
    i.ImageId, i.ImageUrl, i.AltText, i.SortOrder, i.IsMain
FROM [store].[ProductImages] i
WHERE i.ProductId = @ProductId
ORDER BY i.IsMain DESC, i.SortOrder, i.ImageId;
