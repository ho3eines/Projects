-- =============================================
-- Tarazin.Data/Scripts/central/DatabaseStorageInfo.sql
-- Schema: central
-- Cross-schema: accounting, currency
-- Query. اثبات مقصد واقعی persistence برای صفحهٔ /diag و لاگ startup.
-- =============================================
SELECT
    CONVERT(NVARCHAR(128), SERVERPROPERTY(N'ServerName')) AS ServerName,
    DB_NAME() AS DatabaseName,
    (
        SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), f.physical_name), N' | ')
               WITHIN GROUP (ORDER BY f.file_id)
        FROM sys.database_files f
    ) AS DataFiles,
    CAST(CASE WHEN OBJECT_ID(N'accounting.BaseDetil', N'U') IS NULL THEN 0 ELSE 1 END AS BIT) AS AccountingTablesReady,
    CAST(CASE WHEN OBJECT_ID(N'currency.PriceRates', N'U') IS NULL THEN 0 ELSE 1 END AS BIT) AS CurrencyTablesReady,
    CASE WHEN OBJECT_ID(N'accounting.BaseDetil', N'U') IS NULL THEN 0
         ELSE (SELECT COUNT_BIG(*) FROM [accounting].[BaseDetil]) END AS BaseDetilCount,
    CASE WHEN OBJECT_ID(N'accounting.BaseDetilLink', N'U') IS NULL THEN 0
         ELSE (SELECT COUNT_BIG(*) FROM [accounting].[BaseDetilLink]) END AS BaseDetilLinkCount,
    CASE WHEN OBJECT_ID(N'currency.PriceRates', N'U') IS NULL THEN 0
         ELSE (SELECT COUNT_BIG(*) FROM [currency].[PriceRates]) END AS PriceRateCount,
    CASE WHEN OBJECT_ID(N'currency.RateHistory', N'U') IS NULL THEN 0
         ELSE (SELECT COUNT_BIG(*) FROM [currency].[RateHistory]) END AS RateHistoryCount;
