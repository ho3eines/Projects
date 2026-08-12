-- =============================================
-- TarazinApp/Data/Scripts/inventory/_Seed.sql
-- Schema: inventory (انبار آمل)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [inventory].[Warehouses])
BEGIN
    INSERT INTO [inventory].[Warehouses] (WarehouseCode, Title, Location, IsActive, CreatedAt)
    VALUES
        (N'WH-01', N'انبار اصلی آمل', N'آمل، شهرک صنعتی', 1, SYSUTCDATETIME()),
        (N'WH-02', N'انبار طلا و جواهر', N'آمل، بازار', 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [inventory].[Items])
BEGIN
    INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, StockQty, UnitPrice, IsActive, CreatedAt)
    VALUES
        (N'GOLD-24',  N'طلای ۲۴ عیار (گرم)',      N'طلا',    N'گرم',  1200, 38000000, 1, SYSUTCDATETIME()),
        (N'GOLD-18',  N'طلای ۱۸ عیار (گرم)',      N'طلا',    N'گرم',  3500, 28000000, 1, SYSUTCDATETIME()),
        (N'SIKKEH',   N'سکه امامی',               N'سکه',    N'عدد',   85, 62000000, 1, SYSUTCDATETIME()),
        (N'CHAIN-01', N'زنجیر طلا طرح دار',       N'مصنوعات',N'عدد',   40, 45000000, 1, SYSUTCDATETIME()),
        (N'RING-01',  N'انگشتر طلا',              N'مصنوعات',N'عدد',   60, 28000000, 1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [inventory].[Movements])
BEGIN
    INSERT INTO [inventory].[Movements] (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, MovementDate, Description, Status, CreatedBy)
    VALUES
        (N'MV-00001', N'Receipt', 1, 2, 200, 38000000, CAST(SYSDATETIME() AS DATE), N'رسید اولیه طلای ۲۴ عیار', N'Posted', N'seed'),
        (N'MV-00002', N'Receipt', 2, 2, 500, 28000000, CAST(SYSDATETIME() AS DATE), N'رسید اولیه طلای ۱۸ عیار', N'Posted', N'seed'),
        (N'MV-00003', N'Receipt', 3, 2,  20, 62000000, CAST(SYSDATETIME() AS DATE), N'رسید اولیه سکه امامی',   N'Posted', N'seed'),
        (N'MV-00004', N'Issue',   2, 2,  10, 28000000, CAST(SYSDATETIME() AS DATE), N'حواله فروش نمونه',      N'Posted', N'seed');

    -- Sync stock with seeded movements (idempotent block).
    UPDATE [inventory].[Items] SET StockQty = 0;
    UPDATE i SET i.StockQty = ISNULL(s.Qty, 0)
    FROM [inventory].[Items] i
    LEFT JOIN (
        SELECT ItemId, SUM(CASE WHEN MovementType IN (N'Receipt', N'Adjustment') THEN Qty ELSE -Qty END) AS Qty
        FROM [inventory].[Movements] WHERE IsDeleted = 0
        GROUP BY ItemId
    ) s ON s.ItemId = i.ItemId;
END
