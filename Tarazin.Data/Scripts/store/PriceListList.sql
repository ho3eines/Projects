-- =============================================
-- Tarazin.Data/Scripts/store/PriceListList.sql
-- Schema: store
-- Query. لیست لیست‌های قیمت با نام فروشگاه و شمار قیمت‌ها.
-- =============================================
SELECT
    pl.PriceListId,
    pl.CompanyId,
    pl.Code,
    pl.Title,
    pl.StoreId,
    s.Title AS StoreTitle,
    pl.CurrencyCode,
    pl.IsActive,
    pl.CreatedAt,
    (SELECT COUNT(*) FROM [store].[ProductPrices] pp
      WHERE pp.PriceListId = pl.PriceListId AND pp.IsDeleted = 0) AS PriceCount
FROM [store].[PriceLists] pl
LEFT JOIN [store].[Stores] s ON s.StoreId = pl.StoreId
WHERE pl.CompanyId = @CompanyId
  AND pl.IsDeleted = 0
  AND (@PriceListId IS NULL OR pl.PriceListId = @PriceListId)
  AND (@StoreId IS NULL OR pl.StoreId = @StoreId OR pl.StoreId IS NULL)
ORDER BY pl.Code;
