-- =============================================
-- Tarazin.Data/Scripts/goldshop/DashboardSummary.sql
-- Schema: goldshop
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = CAST(SYSDATETIME() AS DATE) AND CompanyId = @CompanyId) AS TodaySales,
    (SELECT ISNULL(SUM(TotalAmount), 0) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = CAST(SYSDATETIME() AS DATE) AND CompanyId = @CompanyId) AS TodayAmount,
    (SELECT COUNT(*) FROM [goldshop].[GoldPrices] WHERE IsDeleted = 0 AND CompanyId = @CompanyId) AS PriceCount,
    (SELECT TOP 1 PricePerGram FROM [goldshop].[GoldPrices]
     WHERE ItemCode = N'XAU-24' AND IsDeleted = 0 AND CompanyId = @CompanyId ORDER BY UpdatedAt DESC) AS Gold24Price;
