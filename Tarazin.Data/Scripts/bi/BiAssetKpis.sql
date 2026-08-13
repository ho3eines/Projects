-- =============================================
-- Tarazin.Data/Scripts/bi/BiAssetKpis.sql
-- Schema: bi
-- Cross-schema: assets
-- Query. داشبورد اموال ثابت (§73): ارزش/تعداد/استهلاک/ارزش دفتری/اسقاطی.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

WITH assets AS (
    SELECT a.*,
           CASE WHEN a.UsefulLifeMonths > 0
                THEN ROUND((a.PurchaseCost - a.ResidualValue) / a.UsefulLifeMonths, 0) ELSE 0 END AS MonthlyDep,
           CASE WHEN a.UsefulLifeMonths > 0
                THEN CASE WHEN DATEDIFF(MONTH, a.PurchaseDate, @Today) < 0 THEN 0
                          WHEN DATEDIFF(MONTH, a.PurchaseDate, @Today) > a.UsefulLifeMonths THEN a.UsefulLifeMonths
                          ELSE DATEDIFF(MONTH, a.PurchaseDate, @Today) END
                ELSE 0 END AS ElapsedMonths
    FROM [assets].[FixedAssets] a
    WHERE a.IsDeleted = 0
)
SELECT N'fa_count' AS KpiKey, N'تعداد دارایی‌ها' AS Title, ISNULL((SELECT COUNT(*) FROM assets), 0) AS Amount,
       NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent, N'دارایی' AS Unit,
       N'/bi/assets' AS Link, N'دارایی‌های غیرحذف' AS Formula, N'assets' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'fa_cost', N'بهای تمام‌شدهٔ دارایی‌ها', ISNULL((SELECT SUM(PurchaseCost) FROM assets), 0), NULL, NULL, NULL,
       N'IRR', N'/bi/assets', N'∑ بهای خرید', N'assets', N'Neutral'
UNION ALL SELECT N'fa_accum_dep', N'استهلاک انباشته', ISNULL((SELECT SUM(MonthlyDep * ElapsedMonths) FROM assets), 0), NULL, NULL, NULL,
       N'IRR', N'/bi/assets', N'∑ (استهلاک ماهانه × ماه‌های گذشته)', N'assets', N'Neutral'
UNION ALL SELECT N'fa_netbook', N'ارزش دفتری', ISNULL((SELECT SUM(PurchaseCost - MonthlyDep * ElapsedMonths) FROM assets), 0), NULL, NULL, NULL,
       N'IRR', N'/bi/assets', N'∑ (بها − استهلاک انباشته)', N'assets', N'Neutral'
UNION ALL SELECT N'fa_scrapped', N'دارایی‌های اسقاطی', ISNULL((SELECT COUNT(*) FROM assets WHERE Status = N'Scrapped'), 0), NULL, NULL, NULL,
       N'دارایی', N'/bi/assets', N'دارایی‌های با وضعیت Scrapped', N'assets', N'Neutral'
UNION ALL SELECT N'fa_transferred', N'دارایی‌های منتقل‌شده', ISNULL((SELECT COUNT(*) FROM assets WHERE Status = N'Transferred'), 0), NULL, NULL, NULL,
       N'دارایی', N'/bi/assets', N'دارایی‌های با وضعیت Transferred', N'assets', N'Neutral';
