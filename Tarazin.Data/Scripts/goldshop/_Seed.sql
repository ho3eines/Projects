-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/goldshop/_Seed.sql
-- Schema: goldshop
-- Endpoint: execute (startup)
-- =============================================
-- Multi-Company seed: use first company for default data
DECLARE @SeedCompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
IF @SeedCompanyId IS NULL
BEGIN
    -- No company yet — central seed will create it; this seed will run again on next startup
    RETURN;
END


IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldItems] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [goldshop].[GoldItems] (ItemCode, Title, Purity, IsActive, CreatedAt, CompanyId)
    VALUES
        (N'XAU-24',       N'طلای ۲۴ عیار (گرم)',      24.00, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'XAU-18',       N'طلای ۱۸ عیار (گرم)',      18.00, 1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'SIKKEH-EMAMI', N'سکه امامی',               NULL,  1, SYSUTCDATETIME(), @SeedCompanyId),
        (N'CHAIN-GOLD',   N'زنجیر طلا',               18.00, 1, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldPrices] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [goldshop].[GoldPrices] (ItemCode, Title, PricePerGram, RateToIRR, UpdatedAt, CompanyId)
    VALUES
        (N'XAU-24',       N'طلای ۲۴ عیار (گرم)', 38000000, NULL, SYSUTCDATETIME(), @SeedCompanyId),
        (N'XAU-18',       N'طلای ۱۸ عیار (گرم)', 28000000, NULL, SYSUTCDATETIME(), @SeedCompanyId),
        (N'SIKKEH-EMAMI', N'سکه امامی',         62000000, NULL, SYSUTCDATETIME(), @SeedCompanyId);
END

IF NOT EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] WHERE CompanyId = @SeedCompanyId)
BEGIN
    INSERT INTO [goldshop].[SaleInvoices]
        (InvoiceNumber, InvoiceDate, CustomerName, ItemCode, WeightGram, Workmanship, Profit, Tax, TotalAmount, Status, CreatedBy, CompanyId)
    VALUES
        (N'GINV-00001', CAST(SYSDATETIME() AS DATE), N'مشتری نقدی', N'XAU-18', 5.000, 3500000, 2500000, 540000, 180540000, N'Issued', N'seed', @SeedCompanyId);
END