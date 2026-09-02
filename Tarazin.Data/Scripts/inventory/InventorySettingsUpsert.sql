-- =============================================
-- Tarazin.Data/Scripts/inventory/InventorySettingsUpsert.sql
-- Schema: inventory
-- Execute. ثبت/به‌روزرسانی تنظیمات انبار شرکت فعال.
-- =============================================
IF @CostingMethod IS NOT NULL AND @CostingMethod NOT IN (N'WeightedAverage', N'FIFO', N'LIFO')
    THROW 51037, N'روش قیمت‌گذاری نامعتبر است (WeightedAverage/FIFO/LIFO).', 1;

IF EXISTS (SELECT 1 FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId)
    UPDATE [inventory].[InventorySettings]
    SET CostingMethod = ISNULL(@CostingMethod, CostingMethod),
        InventoryAccountId = ISNULL(@InventoryAccountId, InventoryAccountId),
        InventoryAccountCode = ISNULL(@InventoryAccountCode, InventoryAccountCode),
        InventoryAccountTitle = ISNULL(@InventoryAccountTitle, InventoryAccountTitle),
        ReceiptContraAccountId = ISNULL(@ReceiptContraAccountId, ReceiptContraAccountId),
        ReceiptContraAccountCode = ISNULL(@ReceiptContraAccountCode, ReceiptContraAccountCode),
        ReceiptContraAccountTitle = ISNULL(@ReceiptContraAccountTitle, ReceiptContraAccountTitle),
        IssueContraAccountId = ISNULL(@IssueContraAccountId, IssueContraAccountId),
        IssueContraAccountCode = ISNULL(@IssueContraAccountCode, IssueContraAccountCode),
        IssueContraAccountTitle = ISNULL(@IssueContraAccountTitle, IssueContraAccountTitle),
        AdjustmentAccountId = ISNULL(@AdjustmentAccountId, AdjustmentAccountId),
        AdjustmentAccountCode = ISNULL(@AdjustmentAccountCode, AdjustmentAccountCode),
        AdjustmentAccountTitle = ISNULL(@AdjustmentAccountTitle, AdjustmentAccountTitle),
        DefaultWarehouseId = ISNULL(@DefaultWarehouseId, DefaultWarehouseId),
        DefaultSubWarehouseId = ISNULL(@DefaultSubWarehouseId, DefaultSubWarehouseId),
        IsEnabled = ISNULL(@IsEnabled, IsEnabled),
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @UpdatedBy
    WHERE CompanyId = @CompanyId;
ELSE
    INSERT INTO [inventory].[InventorySettings]
        (CompanyId, CostingMethod,
         InventoryAccountId, InventoryAccountCode, InventoryAccountTitle,
         ReceiptContraAccountId, ReceiptContraAccountCode, ReceiptContraAccountTitle,
         IssueContraAccountId, IssueContraAccountCode, IssueContraAccountTitle,
         AdjustmentAccountId, AdjustmentAccountCode, AdjustmentAccountTitle,
         DefaultWarehouseId, DefaultSubWarehouseId, IsEnabled, UpdatedAt, UpdatedBy)
    VALUES
        (@CompanyId, ISNULL(@CostingMethod, N'WeightedAverage'),
         @InventoryAccountId, @InventoryAccountCode, @InventoryAccountTitle,
         @ReceiptContraAccountId, @ReceiptContraAccountCode, @ReceiptContraAccountTitle,
         @IssueContraAccountId, @IssueContraAccountCode, @IssueContraAccountTitle,
         @AdjustmentAccountId, @AdjustmentAccountCode, @AdjustmentAccountTitle,
         @DefaultWarehouseId, @DefaultSubWarehouseId, ISNULL(@IsEnabled, 1), SYSUTCDATETIME(), @UpdatedBy);
