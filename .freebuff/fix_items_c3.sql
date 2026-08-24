SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId=3 AND ItemCode=N'GOLD-24')
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
    VALUES (N'GOLD-24', N'طلای ۲۴ عیار (گرم)', N'طلا', N'گرم', 1200, 38000000, 1, SYSUTCDATETIME(), 3);
IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId=3 AND ItemCode=N'GOLD-18')
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
    VALUES (N'GOLD-18', N'طلای ۱۸ عیار (گرم)', N'طلا', N'گرم', 3500, 28000000, 1, SYSUTCDATETIME(), 3);
IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId=3 AND ItemCode=N'SIKKEH')
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
    VALUES (N'SIKKEH', N'سکه امامی', N'سکه', N'عدد', 85, 62000000, 1, SYSUTCDATETIME(), 3);
IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId=3 AND ItemCode=N'CHAIN-01')
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
    VALUES (N'CHAIN-01', N'زنجیر طلا طرح دار', N'مصنوعات', N'عدد', 40, 45000000, 1, SYSUTCDATETIME(), 3);
IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId=3 AND ItemCode=N'RING-01')
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
    VALUES (N'RING-01', N'انگشتر طلا', N'مصنوعات', N'عدد', 60, 28000000, 1, SYSUTCDATETIME(), 3);
SELECT ItemCode, ItemTitle, StockQty FROM inventory.Items WHERE CompanyId=3 ORDER BY ItemCode;
