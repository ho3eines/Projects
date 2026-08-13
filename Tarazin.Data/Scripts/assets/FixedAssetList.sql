-- =============================================
-- Tarazin.Data/Scripts/assets/FixedAssetList.sql
-- Schema: assets
-- Query. فهرست اموال ثابت با استهلاک محاسبه‌شده (خط مستقیم).
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

SELECT a.AssetId, a.AssetCode, a.Title, a.Category, a.PurchaseDate, a.PurchaseCost,
       a.UsefulLifeMonths, a.ResidualValue, a.Status, a.IsActive, a.IsDeleted,
       a.CreatedAt, a.UpdatedAt, a.CreatedBy, a.UpdatedBy,
       -- استهلاک ماهانه = (بها − ارزش اسقاط) ÷ عمر مفید
       CASE WHEN a.UsefulLifeMonths > 0
            THEN ROUND((a.PurchaseCost - a.ResidualValue) / a.UsefulLifeMonths, 0)
            ELSE 0 END AS MonthlyDepreciation,
       -- استهلاک انباشته تا امروز (ماه‌های گذشته از خرید)
       CASE WHEN a.UsefulLifeMonths > 0
            THEN ROUND((a.PurchaseCost - a.ResidualValue) / a.UsefulLifeMonths *
                       CASE WHEN DATEDIFF(MONTH, a.PurchaseDate, @Today) < 0 THEN 0
                            WHEN DATEDIFF(MONTH, a.PurchaseDate, @Today) > a.UsefulLifeMonths THEN a.UsefulLifeMonths
                            ELSE DATEDIFF(MONTH, a.PurchaseDate, @Today) END, 0)
            ELSE 0 END AS AccumulatedDepreciation,
       -- ارزش دفتری = بها − استهلاک انباشته
       CASE WHEN a.UsefulLifeMonths > 0
            THEN ROUND(a.PurchaseCost -
                       (a.PurchaseCost - a.ResidualValue) / a.UsefulLifeMonths *
                       CASE WHEN DATEDIFF(MONTH, a.PurchaseDate, @Today) < 0 THEN 0
                            WHEN DATEDIFF(MONTH, a.PurchaseDate, @Today) > a.UsefulLifeMonths THEN a.UsefulLifeMonths
                            ELSE DATEDIFF(MONTH, a.PurchaseDate, @Today) END, 0)
            ELSE a.PurchaseCost END AS NetBookValue
FROM [assets].[FixedAssets] a
WHERE a.IsDeleted = 0
  AND (@OnlyActive = 0 OR a.IsActive = 1)
ORDER BY a.PurchaseDate DESC, a.AssetCode;
