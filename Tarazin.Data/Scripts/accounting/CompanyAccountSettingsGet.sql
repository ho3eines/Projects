-- =============================================
-- Tarazin.Data/Scripts/accounting/CompanyAccountSettingsGet.sql
-- Schema: accounting
-- تنظیمات سراسری حسابداری شرکت فعال (گروه‌های تفصیلی مشترک بین ماژول‌ها).
-- =============================================
SELECT s.CompanyId,
       s.CustomerAccountGroupId, cg.Title AS CustomerAccountGroupTitle, cg.GroupCode AS CustomerAccountGroupCode,
       s.SupplierAccountGroupId, sg.Title AS SupplierAccountGroupTitle, sg.GroupCode AS SupplierAccountGroupCode,
       s.InventoryAccountGroupId, ig.Title AS InventoryAccountGroupTitle, ig.GroupCode AS InventoryAccountGroupCode,
       s.UpdatedAt, s.UpdatedBy
FROM [accounting].[CompanyAccountSettings] s
LEFT JOIN [accounting].[AccountGroups] cg ON cg.AccountGroupId = s.CustomerAccountGroupId
LEFT JOIN [accounting].[AccountGroups] sg ON sg.AccountGroupId = s.SupplierAccountGroupId
LEFT JOIN [accounting].[AccountGroups] ig ON ig.AccountGroupId = s.InventoryAccountGroupId
WHERE s.CompanyId = @CompanyId;
