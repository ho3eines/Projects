-- =============================================
-- HermesApp/Data/Scripts/goldshop/DashboardSummary.sql
-- Schema: goldshop
-- Query. One row of stats.
-- =============================================
SELECT
    (SELECT COUNT(*) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = CAST(SYSDATETIME() AS DATE)) AS TodaySales,
    (SELECT ISNULL(SUM(TotalAmount), 0) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = CAST(SYSDATETIME() AS DATE)) AS TodayAmount,
    (SELECT COUNT(*) FROM [goldshop].[GoldPrices]) AS PriceCount,
    (SELECT TOP 1 PricePerGram FROM [goldshop].[GoldPrices] WHERE ItemCode = N'XAU-24' ORDER BY UpdatedAt DESC) AS Gold24Price;
