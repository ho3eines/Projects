-- =============================================
-- Tarazin.Shared/Data/Scripts/goldshop/_Seed.sql
-- Schema: goldshop
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldItems])
BEGIN
    INSERT INTO [goldshop].[GoldItems] (ItemCode, Title, Purity, IsActive, CreatedAt)
    VALUES
        (N'XAU-24',       N'طلای ۲۴ عیار (گرم)',      24.00, 1, SYSUTCDATETIME()),
        (N'XAU-18',       N'طلای ۱۸ عیار (گرم)',      18.00, 1, SYSUTCDATETIME()),
        (N'SIKKEH-EMAMI', N'سکه امامی',               NULL,  1, SYSUTCDATETIME()),
        (N'CHAIN-GOLD',   N'زنجیر طلا',               18.00, 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldPrices])
BEGIN
    INSERT INTO [goldshop].[GoldPrices] (ItemCode, Title, PricePerGram, RateToIRR, UpdatedAt)
    VALUES
        (N'XAU-24',       N'طلای ۲۴ عیار (گرم)', 38000000, NULL, SYSUTCDATETIME()),
        (N'XAU-18',       N'طلای ۱۸ عیار (گرم)', 28000000, NULL, SYSUTCDATETIME()),
        (N'SIKKEH-EMAMI', N'سکه امامی',         62000000, NULL, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices])
BEGIN
    INSERT INTO [goldshop].[SaleInvoices]
        (InvoiceNumber, InvoiceDate, CustomerName, ItemCode, WeightGram, Workmanship, Profit, Tax, TotalAmount, Status, CreatedBy)
    VALUES
        (N'GINV-00001', CAST(SYSDATETIME() AS DATE), N'مشتری نقدی', N'XAU-18', 5.000, 3500000, 2500000, 540000, 180540000, N'Issued', N'seed');
END
