-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/inventory/_Seed.sql
-- Schema: inventory (انبار آمل)
-- Endpoint: execute (startup)
-- =============================================
-- Multi-Company seed: for EVERY active company.
DECLARE inv_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @SeedCompanyId INT;
OPEN inv_cursor;
FETCH NEXT FROM inv_cursor INTO @SeedCompanyId;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [inventory].[Warehouses] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [inventory].[Warehouses] (WarehouseCode, Title, Location, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'WH-01', N'انبار اصلی', N'دفتر مرکزی', 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'WH-02', N'انبار طلا و جواهر', N'بازار', 1, SYSUTCDATETIME(), @SeedCompanyId);
    END

    IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId = @SeedCompanyId AND ItemCode IN (N'GOLD-24',N'GOLD-18',N'SIKKEH',N'CHAIN-01',N'RING-01'))
    BEGIN
        INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'GOLD-24',  N'طلای ۲۴ عیار (گرم)',      N'طلا',    N'گرم',  1200, 38000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'GOLD-18',  N'طلای ۱۸ عیار (گرم)',      N'طلا',    N'گرم',  3500, 28000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'SIKKEH',   N'سکه امامی',               N'سکه',    N'عدد',   85, 62000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'CHAIN-01', N'زنجیر طلا طرح دار',       N'مصنوعات',N'عدد',   40, 45000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'RING-01',  N'انگشتر طلا',              N'مصنوعات',N'عدد',   60, 28000000, 1, SYSUTCDATETIME(), @SeedCompanyId);
    END

    -- رسید اولیه برای هر شرکت (موجودی طلا برای فروش)
    IF NOT EXISTS (SELECT 1 FROM [inventory].[Movements] WHERE CompanyId = @SeedCompanyId AND Description LIKE N'%اولیه%')
    BEGIN
        DECLARE @WhGold INT = (SELECT TOP 1 WarehouseId FROM [inventory].[Warehouses] WHERE CompanyId=@SeedCompanyId ORDER BY WarehouseId);
        INSERT INTO [inventory].[Movements] (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
        SELECT N'MV-INIT-' + RIGHT(N'00000' + CAST(ROW_NUMBER() OVER (ORDER BY i.ItemId) AS NVARCHAR(10)), 5),
               N'Receipt', i.ItemId, @WhGold, i.StockQty, i.UnitPrice, CAST(SYSDATETIME() AS DATE),
               N'رسید اولیه ' + i.ItemTitle, N'Posted', N'seed', @SeedCompanyId
        FROM [inventory].[Items] i
        WHERE i.CompanyId = @SeedCompanyId AND i.IsDeleted = 0;
    END

    FETCH NEXT FROM inv_cursor INTO @SeedCompanyId;
END
CLOSE inv_cursor;
DEALLOCATE inv_cursor;