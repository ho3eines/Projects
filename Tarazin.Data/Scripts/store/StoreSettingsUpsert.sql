-- =============================================
-- Tarazin.Data/Scripts/store/StoreSettingsUpsert.sql
-- Schema: store
-- Execute. ذخیرهٔ تنظیمات فروشگاه (لینک‌های حسابداری/خزانه/انبار).
-- =============================================
IF EXISTS (SELECT 1 FROM [store].[StoreSettings] WHERE CompanyId = @CompanyId)
    UPDATE [store].[StoreSettings]
    SET InventoryWarehouseId = @InventoryWarehouseId,
        SalesAccountId = @SalesAccountId, SalesAccountCode = @SalesAccountCode, SalesAccountTitle = @SalesAccountTitle,
        InventoryAccountId = @InventoryAccountId, InventoryAccountCode = @InventoryAccountCode, InventoryAccountTitle = @InventoryAccountTitle,
        CashAccountId = @CashAccountId, CashAccountCode = @CashAccountCode, CashAccountTitle = @CashAccountTitle,
        BankChartAccountId = @BankChartAccountId, BankChartAccountCode = @BankChartAccountCode, BankChartAccountTitle = @BankChartAccountTitle,
        CashBoxId = @CashBoxId, BankAccountId = @BankAccountId,
        IsEnabled = ISNULL(@IsEnabled, IsEnabled), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
    WHERE CompanyId = @CompanyId;
ELSE
    INSERT INTO [store].[StoreSettings]
        (CompanyId, InventoryWarehouseId,
         SalesAccountId, SalesAccountCode, SalesAccountTitle,
         InventoryAccountId, InventoryAccountCode, InventoryAccountTitle,
         CashAccountId, CashAccountCode, CashAccountTitle,
         BankChartAccountId, BankChartAccountCode, BankChartAccountTitle,
         CashBoxId, BankAccountId, IsEnabled, UpdatedAt, UpdatedBy)
    VALUES
        (@CompanyId, @InventoryWarehouseId,
         @SalesAccountId, @SalesAccountCode, @SalesAccountTitle,
         @InventoryAccountId, @InventoryAccountCode, @InventoryAccountTitle,
         @CashAccountId, @CashAccountCode, @CashAccountTitle,
         @BankChartAccountId, @BankChartAccountCode, @BankChartAccountTitle,
         @CashBoxId, @BankAccountId, ISNULL(@IsEnabled, 1), SYSUTCDATETIME(), @UpdatedBy);
