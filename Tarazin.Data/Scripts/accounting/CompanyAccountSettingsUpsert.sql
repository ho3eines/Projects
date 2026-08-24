-- =============================================
-- Tarazin.Data/Scripts/accounting/CompanyAccountSettingsUpsert.sql
-- Schema: accounting
-- ثبت تنظیمات سراسری حسابداری شرکت (گروه‌های تفصیلی مشترک).
-- =============================================
IF EXISTS (SELECT 1 FROM [accounting].[CompanyAccountSettings] WHERE CompanyId = @CompanyId)
    UPDATE [accounting].[CompanyAccountSettings]
    SET CustomerAccountGroupId = @CustomerAccountGroupId,
        SupplierAccountGroupId = @SupplierAccountGroupId,
        InventoryAccountGroupId = @InventoryAccountGroupId,
        UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
    WHERE CompanyId = @CompanyId;
ELSE
    INSERT INTO [accounting].[CompanyAccountSettings]
        (CompanyId, CustomerAccountGroupId, SupplierAccountGroupId, InventoryAccountGroupId, UpdatedAt, UpdatedBy)
    VALUES
        (@CompanyId, @CustomerAccountGroupId, @SupplierAccountGroupId, @InventoryAccountGroupId, SYSUTCDATETIME(), @UpdatedBy);
