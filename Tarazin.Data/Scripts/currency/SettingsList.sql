-- =============================================
-- Tarazin.Data/Scripts/currency/SettingsList.sql
-- Schema: currency
-- Query. تنظیمات ماژول ارز (واحد پایه، فاصلهٔ بروزرسانی، …).
-- =============================================
SELECT SettingKey, SettingValue, Description
FROM [currency].[Settings]
ORDER BY SettingKey;
