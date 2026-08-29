-- =============================================
-- Tarazin.Data/Scripts/accounting/CompanyAccountSettingsGet.sql
-- Schema: accounting
-- تنظیمات سراسری حسابداری شرکت فعال (گروه‌های تفصیلی مشترک + اطلاعات چاپ).
-- =============================================
SELECT s.CompanyId,
       s.CustomerAccountGroupId, cg.Title AS CustomerAccountGroupTitle, cg.GroupCode AS CustomerAccountGroupCode,
       s.SupplierAccountGroupId, sg.Title AS SupplierAccountGroupTitle, sg.GroupCode AS SupplierAccountGroupCode,
       s.InventoryAccountGroupId, ig.Title AS InventoryAccountGroupTitle, ig.GroupCode AS InventoryAccountGroupCode,
       s.CompanyName, s.Address, s.LogoPath, s.QrBaseUrl, s.QrEnabled,
       s.UpdatedAt, s.UpdatedBy
FROM [accounting].[CompanyAccountSettings] s
LEFT JOIN [accounting].[AccountGroups] cg ON cg.AccountGroupId = s.CustomerAccountGroupId
    AND (cg.CompanyId = s.CompanyId OR cg.CompanyId IS NULL)
LEFT JOIN [accounting].[AccountGroups] sg ON sg.AccountGroupId = s.SupplierAccountGroupId
    AND (sg.CompanyId = s.CompanyId OR sg.CompanyId IS NULL)
LEFT JOIN [accounting].[AccountGroups] ig ON ig.AccountGroupId = s.InventoryAccountGroupId
    AND (ig.CompanyId = s.CompanyId OR ig.CompanyId IS NULL)
WHERE s.CompanyId = @CompanyId
  AND EXISTS (SELECT 1 FROM [central].[Companies] c
              WHERE c.CompanyId = s.CompanyId AND c.IsDeleted = 0);