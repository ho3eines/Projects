-- =============================================
-- Tarazin.Data/Scripts/store/BrandList.sql
-- Schema: store
-- Query. فهرست برندها (برای پیکر و مدیریت).
-- =============================================
SELECT
    b.BrandId,
    b.CompanyId,
    b.BrandCode,
    b.Title,
    b.LogoUrl,
    b.[Description],
    b.IsActive,
    (SELECT COUNT(*) FROM [store].[Products] p
     WHERE p.BrandId = b.BrandId AND p.IsDeleted = 0) AS ProductCount
FROM [store].[Brands] b
WHERE b.CompanyId = @CompanyId
  AND b.IsDeleted = 0
  AND (@BrandId IS NULL OR b.BrandId = @BrandId)
ORDER BY b.Title;
