-- =============================================
-- Tarazin.Data/Scripts/accounting/CompanyAccountSettingsUpsert.sql
-- Schema: accounting
-- ثبت تنظیمات سراسری حسابداری شرکت (گروه‌های تفصیلی + اطلاعات چاپ).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [central].[Companies] WHERE CompanyId = @CompanyId AND IsDeleted = 0)
    THROW 51001, N'شرکت فعال پیدا نشد.', 1;

IF EXISTS (SELECT 1 FROM [accounting].[CompanyAccountSettings] WHERE CompanyId = @CompanyId)
    UPDATE [accounting].[CompanyAccountSettings]
    SET CustomerAccountGroupId = @CustomerAccountGroupId,
        SupplierAccountGroupId = @SupplierAccountGroupId,
        InventoryAccountGroupId = @InventoryAccountGroupId,
        CompanyName = @CompanyName,
        Address = @Address,
        LogoPath = @LogoPath,
        QrBaseUrl = @QrBaseUrl,
        QrEnabled = @QrEnabled,
        UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
    WHERE CompanyId = @CompanyId;
ELSE
    INSERT INTO [accounting].[CompanyAccountSettings]
        (CompanyId, CustomerAccountGroupId, SupplierAccountGroupId, InventoryAccountGroupId,
         CompanyName, Address, LogoPath, QrBaseUrl, QrEnabled, UpdatedAt, UpdatedBy)
    VALUES
        (@CompanyId, @CustomerAccountGroupId, @SupplierAccountGroupId, @InventoryAccountGroupId,
         @CompanyName, @Address, @LogoPath, @QrBaseUrl, @QrEnabled, SYSUTCDATETIME(), @UpdatedBy);