-- =============================================
-- Tarazin.Data/Scripts/inventory/InventorySettingsGet.sql
-- Schema: inventory
-- Query. تنظیمات انبار شرکت فعال: روش قیمت‌گذاری + اتصال به حساب انبار.
-- =============================================
SELECT s.CompanyId,
       s.CostingMethod,
       s.InventoryAccountId, s.InventoryAccountCode, s.InventoryAccountTitle,
       s.ReceiptContraAccountId, s.ReceiptContraAccountCode, s.ReceiptContraAccountTitle,
       s.IssueContraAccountId, s.IssueContraAccountCode, s.IssueContraAccountTitle,
       s.AdjustmentAccountId, s.AdjustmentAccountCode, s.AdjustmentAccountTitle,
       s.DefaultWarehouseId, w.Title AS DefaultWarehouseTitle,
       s.DefaultSubWarehouseId, sw.Title AS DefaultSubWarehouseTitle,
       s.IsEnabled, s.UpdatedAt, s.UpdatedBy
FROM [inventory].[InventorySettings] s
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = s.DefaultWarehouseId
LEFT JOIN [inventory].[SubWarehouses] sw ON sw.SubWarehouseId = s.DefaultSubWarehouseId
WHERE s.CompanyId = @CompanyId;
