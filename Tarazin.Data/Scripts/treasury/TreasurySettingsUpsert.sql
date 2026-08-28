-- =============================================
-- Tarazin.Data/Scripts/treasury/TreasurySettingsUpsert.sql
-- Schema: treasury
-- Execute. ثبت تنظیمات اتصال خزانه به حسابداری.
-- =============================================
IF EXISTS (SELECT 1 FROM [treasury].[TreasurySettings] WHERE CompanyId=@CompanyId)
    UPDATE [treasury].[TreasurySettings]
    SET CashAccountId=@CashAccountId, CashAccountCode=@CashAccountCode, CashAccountTitle=@CashAccountTitle,
        BankChartAccountId=@BankChartAccountId, BankChartAccountCode=@BankChartAccountCode, BankChartAccountTitle=@BankChartAccountTitle,
        ReceiveContraAccountId=@ReceiveContraAccountId, ReceiveContraAccountCode=@ReceiveContraAccountCode, ReceiveContraAccountTitle=@ReceiveContraAccountTitle,
        PayContraAccountId=@PayContraAccountId, PayContraAccountCode=@PayContraAccountCode, PayContraAccountTitle=@PayContraAccountTitle,
        CustomerAccountGroupId=@CustomerAccountGroupId, SupplierAccountGroupId=@SupplierAccountGroupId,
        DefaultCashBoxId=@DefaultCashBoxId, DefaultBankAccountId=@DefaultBankAccountId,
        IsEnabled=ISNULL(@IsEnabled, IsEnabled), UpdatedAt=SYSUTCDATETIME(), UpdatedBy=@UpdatedBy
    WHERE CompanyId=@CompanyId;
ELSE
    INSERT INTO [treasury].[TreasurySettings]
        (CompanyId, CashAccountId, CashAccountCode, CashAccountTitle,
         BankChartAccountId, BankChartAccountCode, BankChartAccountTitle,
         ReceiveContraAccountId, ReceiveContraAccountCode, ReceiveContraAccountTitle,
         PayContraAccountId, PayContraAccountCode, PayContraAccountTitle,
         CustomerAccountGroupId, SupplierAccountGroupId,
         DefaultCashBoxId, DefaultBankAccountId, IsEnabled, UpdatedAt, UpdatedBy)
    VALUES
        (@CompanyId, @CashAccountId, @CashAccountCode, @CashAccountTitle,
         @BankChartAccountId, @BankChartAccountCode, @BankChartAccountTitle,
         @ReceiveContraAccountId, @ReceiveContraAccountCode, @ReceiveContraAccountTitle,
         @PayContraAccountId, @PayContraAccountCode, @PayContraAccountTitle,
         @CustomerAccountGroupId, @SupplierAccountGroupId,
         @DefaultCashBoxId, @DefaultBankAccountId, ISNULL(@IsEnabled, 1), SYSUTCDATETIME(), @UpdatedBy);
