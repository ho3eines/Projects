-- =============================================
-- Tarazin.Data/Scripts/store/StoreSettingsGet.sql
-- Schema: store
-- Query. تنظیمات فروشگاه + لینک‌های حسابداری/خزانه/انبار.
-- =============================================
SELECT s.CompanyId, s.InventoryWarehouseId, w.Title AS InventoryWarehouseTitle,
       s.SalesAccountId, ISNULL(s.SalesAccountTitle, sa.Title) AS SalesAccountTitle, s.SalesAccountCode,
       s.InventoryAccountId, ISNULL(s.InventoryAccountTitle, ia.Title) AS InventoryAccountTitle, s.InventoryAccountCode,
       s.CashAccountId, ISNULL(s.CashAccountTitle, ca.Title) AS CashAccountTitle, s.CashAccountCode,
       s.BankChartAccountId, ISNULL(s.BankChartAccountTitle, bca.Title) AS BankChartAccountTitle, s.BankChartAccountCode,
       s.CashBoxId, cb.Title AS CashBoxTitle,
       s.BankAccountId, ba.AccountName AS BankAccountTitle,
       s.IsEnabled, s.UpdatedAt, s.UpdatedBy
FROM [store].[StoreSettings] s
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = s.InventoryWarehouseId
LEFT JOIN [accounting].[ChartOfAccounts] sa ON sa.AccountId = s.SalesAccountId
LEFT JOIN [accounting].[ChartOfAccounts] ia ON ia.AccountId = s.InventoryAccountId
LEFT JOIN [accounting].[ChartOfAccounts] ca ON ca.AccountId = s.CashAccountId
LEFT JOIN [accounting].[ChartOfAccounts] bca ON bca.AccountId = s.BankChartAccountId
LEFT JOIN [treasury].[CashBoxes] cb ON cb.CashBoxId = s.CashBoxId
LEFT JOIN [treasury].[BankAccounts] ba ON ba.AccountId = s.BankAccountId
WHERE s.CompanyId = @CompanyId;
