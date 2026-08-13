-- =============================================
-- Tarazin.Data/Scripts/bi/BiAssetDepreciation.sql
-- Schema: bi
-- Cross-schema: assets
-- Query. نمودار استهلاک (§74): استهلاک ماهانهٔ برنامه‌ریزی‌شدهٔ ۱۲ ماه آینده.
-- خروجی: سری (Bucket=ماه, Label, Value1=استهلاک ماهانه, Value2=استهلاک انباشتهٔ پیش‌بینی‌شده)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

WITH months AS (
    SELECT TOP (12) number AS N
    FROM master..spt_values
    WHERE type = N'P'
    ORDER BY number
),
assets AS (
    SELECT a.PurchaseDate, a.PurchaseCost, a.ResidualValue, a.UsefulLifeMonths
    FROM [assets].[FixedAssets] a
    WHERE a.IsDeleted = 0 AND a.Status = N'Active'
)
SELECT DATEADD(MONTH, m.N, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1)) AS Bucket,
       FORMAT(DATEADD(MONTH, m.N, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1)), 'yyyy/MM') AS Label,
       ISNULL((SELECT SUM(CASE WHEN a.UsefulLifeMonths > 0
                               THEN ROUND((a.PurchaseCost - a.ResidualValue) / a.UsefulLifeMonths, 0) ELSE 0 END)
               FROM assets a
               WHERE DATEADD(MONTH, m.N, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1))
                     BETWEEN DATEFROMPARTS(YEAR(a.PurchaseDate), MONTH(a.PurchaseDate), 1)
                         AND DATEADD(MONTH, a.UsefulLifeMonths, DATEFROMPARTS(YEAR(a.PurchaseDate), MONTH(a.PurchaseDate), 1))), 0) AS Value1,
       ISNULL((SELECT SUM(CASE WHEN a.UsefulLifeMonths > 0
                               THEN ROUND((a.PurchaseCost - a.ResidualValue) / a.UsefulLifeMonths, 0)
                                    * CASE WHEN DATEDIFF(MONTH, a.PurchaseDate, DATEADD(MONTH, m.N, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1))) < 0 THEN 0
                                           WHEN DATEDIFF(MONTH, a.PurchaseDate, DATEADD(MONTH, m.N, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1))) > a.UsefulLifeMonths THEN a.UsefulLifeMonths
                                           ELSE DATEDIFF(MONTH, a.PurchaseDate, DATEADD(MONTH, m.N, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1))) END
                               ELSE 0 END)
               FROM assets a), 0) AS Value2,
       0 AS Value3, 0 AS Value4
FROM months m
ORDER BY m.N;
