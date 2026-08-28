IF EXISTS (SELECT 1 FROM [payroll].[PayrollSettings] WHERE CompanyId = @CompanyId)
BEGIN
    UPDATE [payroll].[PayrollSettings]
    SET PayableAccountCode = @PayableAccountCode,
        InsuranceAccountCode = @InsuranceAccountCode,
        TaxAccountCode = @TaxAccountCode,
        BankAccountCode = @BankAccountCode,
        DocumentPrefix = @DocumentPrefix,
        UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
    WHERE CompanyId = @CompanyId;
END
ELSE
BEGIN
    INSERT INTO [payroll].[PayrollSettings]
        (PayableAccountCode, InsuranceAccountCode, TaxAccountCode, BankAccountCode,
         DocumentPrefix, UpdatedAt, UpdatedBy, CompanyId)
    VALUES
        (@PayableAccountCode, @InsuranceAccountCode, @TaxAccountCode, @BankAccountCode,
         @DocumentPrefix, SYSUTCDATETIME(), @UpdatedBy, @CompanyId);
END
