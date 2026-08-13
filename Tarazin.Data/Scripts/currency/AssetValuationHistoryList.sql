-- =============================================
-- Tarazin.Data/Scripts/currency/AssetValuationHistoryList.sql
-- Schema: currency
-- Query. اسنپ‌شات‌های ارزش دارایی (PRD §51 — مقایسهٔ روز گذشته/امروز).
-- =============================================
SELECT TOP (@TakeSize) SnapshotId, SnapshotDate, TotalRial, CashPart, CurrencyPart,
       GoldPart, CoinPart, MetalPart, CreatedAt, CreatedBy
FROM [currency].[AssetValuationHistory]
ORDER BY SnapshotDate DESC;
