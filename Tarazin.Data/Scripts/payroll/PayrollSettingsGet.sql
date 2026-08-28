SELECT TOP (1)
    SettingId, PayableAccountCode, InsuranceAccountCode, TaxAccountCode,
    BankAccountCode, DocumentPrefix, UpdatedAt, UpdatedBy, CompanyId
FROM [payroll].[PayrollSettings]
WHERE (@CompanyId IS NULL OR CompanyId = @CompanyId)
ORDER BY SettingId DESC;
