-- =============================================
-- Tarazin.Data/Scripts/store/ProductPriceList.sql
-- Schema: store
-- Query. قیمت‌های محصول به تفکیک لیست/فروشگاه.
-- =============================================
SELECT
    pp.PriceId,
    pp.CompanyId,
    pp.PriceListId,
    pl.Title AS PriceListTitle,
    pp.ProductId,
    p.Title AS ProductTitle,
    p.ProductCode,
    pp.StoreId,
    s.Title AS StoreTitle,
    pp.Price,
    p.Price AS BasePrice,
    pp.FromDate,
    pp.ToDate,
    pp.MinQty,
    pp.IsDeleted
FROM [store].[ProductPrices] pp
JOIN [store].[PriceLists] pl ON pl.PriceListId = pp.PriceListId
JOIN [store].[Products] p ON p.ProductId = pp.ProductId
LEFT JOIN [store].[Stores] s ON s.StoreId = pp.StoreId
WHERE pp.CompanyId = @CompanyId
  AND pp.IsDeleted = 0
  AND (@PriceId IS NULL OR pp.PriceId = @PriceId)
  AND (@PriceListId IS NULL OR pp.PriceListId = @PriceListId)
  AND (@ProductId IS NULL OR pp.ProductId = @ProductId)
  AND (@StoreId IS NULL OR pp.StoreId = @StoreId OR pp.StoreId IS NULL)
ORDER BY pl.Code, p.Title;
