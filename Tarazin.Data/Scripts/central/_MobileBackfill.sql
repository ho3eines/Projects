-- Explicit backfill for business tables that have existing rows without
-- CompanyId when multiple companies exist. Run before _MobileSecurity.
-- Cross-schema: accounting, currency, payroll
SET NOCOUNT ON;

DECLARE @DefaultCompanyId INT = (
    SELECT TOP (1) CompanyId
    FROM [central].[Companies]
    WHERE IsDeleted = 0
    ORDER BY CompanyId
);

IF @DefaultCompanyId IS NOT NULL
BEGIN
    IF COL_LENGTH(N'accounting.DocumentLines', N'CompanyId') IS NOT NULL
        UPDATE [accounting].[DocumentLines] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;

    IF COL_LENGTH(N'currency.Wallets', N'CompanyId') IS NOT NULL
        UPDATE [currency].[Wallets] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;

    IF COL_LENGTH(N'payroll.SalaryItems', N'CompanyId') IS NOT NULL
        UPDATE [payroll].[SalaryItems] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;
END
