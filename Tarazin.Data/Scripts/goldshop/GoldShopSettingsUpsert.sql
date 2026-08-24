IF EXISTS (SELECT 1 FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId)
    UPDATE [goldshop].[GoldShopSettings]
    SET InventoryWarehouseId=@InventoryWarehouseId, CustomerAccountGroupId=@CustomerAccountGroupId,
        SupplierAccountGroupId=@SupplierAccountGroupId, InventoryAccountGroupId=@InventoryAccountGroupId,
        SalesAccountId=@SalesAccountId,
        SalesAccountCode=@SalesAccountCode, SalesAccountTitle=@SalesAccountTitle,
        InventoryAccountId=@InventoryAccountId, InventoryAccountCode=@InventoryAccountCode, InventoryAccountTitle=@InventoryAccountTitle,
        TaxPayableAccountId=@TaxPayableAccountId, TaxPayableAccountCode=@TaxPayableAccountCode, TaxPayableAccountTitle=@TaxPayableAccountTitle,
        CashAccountId=@CashAccountId, CashAccountCode=@CashAccountCode, CashAccountTitle=@CashAccountTitle,
        BankAccountId=@BankAccountId,
        CashBoxId=@CashBoxId, BankChartAccountId=@BankChartAccountId,
        BankChartAccountCode=@BankChartAccountCode, BankChartAccountTitle=@BankChartAccountTitle,
        DefaultTaxPercent=ISNULL(@DefaultTaxPercent,DefaultTaxPercent), LaborTaxPercent=ISNULL(@LaborTaxPercent,LaborTaxPercent),
        IsEnabled=ISNULL(@IsEnabled,IsEnabled), UpdatedAt=SYSUTCDATETIME(), UpdatedBy=@UpdatedBy
    WHERE CompanyId=@CompanyId;
ELSE
    INSERT INTO [goldshop].[GoldShopSettings]
        (CompanyId,InventoryWarehouseId,CustomerAccountGroupId,SupplierAccountGroupId,InventoryAccountGroupId,
         SalesAccountId,SalesAccountCode,SalesAccountTitle,
         InventoryAccountId,InventoryAccountCode,InventoryAccountTitle,
         TaxPayableAccountId,TaxPayableAccountCode,TaxPayableAccountTitle,
         CashAccountId,CashAccountCode,CashAccountTitle,
         BankAccountId,CashBoxId,BankChartAccountId,BankChartAccountCode,BankChartAccountTitle,
         DefaultTaxPercent,LaborTaxPercent,IsEnabled,UpdatedAt,UpdatedBy)
    VALUES (@CompanyId,@InventoryWarehouseId,@CustomerAccountGroupId,@SupplierAccountGroupId,@InventoryAccountGroupId,
            @SalesAccountId,@SalesAccountCode,@SalesAccountTitle,
            @InventoryAccountId,@InventoryAccountCode,@InventoryAccountTitle,
            @TaxPayableAccountId,@TaxPayableAccountCode,@TaxPayableAccountTitle,
            @CashAccountId,@CashAccountCode,@CashAccountTitle,
            @BankAccountId,@CashBoxId,@BankChartAccountId,@BankChartAccountCode,@BankChartAccountTitle,
            ISNULL(@DefaultTaxPercent,10),ISNULL(@LaborTaxPercent,10),ISNULL(@IsEnabled,1),SYSUTCDATETIME(),@UpdatedBy);
