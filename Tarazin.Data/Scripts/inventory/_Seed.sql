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

    -- گروه‌های کالا و واحدهای پایه
    DECLARE @GrpGold INT, @GrpCoin INT, @GrpJewelry INT;
    IF NOT EXISTS (SELECT 1 FROM [inventory].[ItemGroups] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [inventory].[ItemGroups] (GroupCode, Title, SortOrder, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'GRP-GOLD', N'طلا', 1, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'GRP-COIN', N'سکه', 2, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'GRP-JWL', N'مصنوعات طلا', 3, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'GRP-GEN', N'سایر کالاها', 9, 1, SYSUTCDATETIME(), @SeedCompanyId);
    END
    SELECT @GrpGold = GroupId FROM [inventory].[ItemGroups] WHERE CompanyId = @SeedCompanyId AND GroupCode = N'GRP-GOLD';
    SELECT @GrpCoin = GroupId FROM [inventory].[ItemGroups] WHERE CompanyId = @SeedCompanyId AND GroupCode = N'GRP-COIN';
    SELECT @GrpJewelry = GroupId FROM [inventory].[ItemGroups] WHERE CompanyId = @SeedCompanyId AND GroupCode = N'GRP-JWL';

    DECLARE @UnitGram INT, @UnitPiece INT;
    IF NOT EXISTS (SELECT 1 FROM [inventory].[Units] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [inventory].[Units] (UnitCode, Title, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'GRAM', N'گرم', 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'PC', N'عدد', 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'KILO', N'کیلوگرم', 1, SYSUTCDATETIME(), @SeedCompanyId);
    END
    SELECT @UnitGram = UnitId FROM [inventory].[Units] WHERE CompanyId = @SeedCompanyId AND UnitCode = N'GRAM';
    SELECT @UnitPiece = UnitId FROM [inventory].[Units] WHERE CompanyId = @SeedCompanyId AND UnitCode = N'PC';

    IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId = @SeedCompanyId AND ItemCode IN (N'GOLD-24',N'GOLD-18',N'SIKKEH',N'CHAIN-01',N'RING-01'))
    BEGIN
        INSERT INTO [inventory].[Items] (ItemCode, ItemTitle, Category, Unit, GroupId, UnitId, StockQty, UnitPrice, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'GOLD-24',  N'طلای ۲۴ عیار (گرم)',      N'طلا',    N'گرم',  @GrpGold,    @UnitGram,   1200, 38000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'GOLD-18',  N'طلای ۱۸ عیار (گرم)',      N'طلا',    N'گرم',  @GrpGold,    @UnitGram,   3500, 28000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'SIKKEH',   N'سکه امامی',               N'سکه',    N'عدد',  @GrpCoin,    @UnitPiece,    85, 62000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'CHAIN-01', N'زنجیر طلا طرح دار',       N'مصنوعات',N'عدد',  @GrpJewelry, @UnitPiece,    40, 45000000, 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'RING-01',  N'انگشتر طلا',              N'مصنوعات',N'عدد',  @GrpJewelry, @UnitPiece,    60, 28000000, 1, SYSUTCDATETIME(), @SeedCompanyId);
    END

    -- رسید اولیه برای هر شرکت (موجودی طلا برای فروش) + لایه‌های موجودی
    IF NOT EXISTS (SELECT 1 FROM [inventory].[Movements] WHERE CompanyId = @SeedCompanyId AND Description LIKE N'%اولیه%')
    BEGIN
        DECLARE @WhGold INT = (SELECT TOP 1 WarehouseId FROM [inventory].[Warehouses] WHERE CompanyId=@SeedCompanyId ORDER BY WarehouseId);
        INSERT INTO [inventory].[Movements] (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
        SELECT N'MV-INIT-' + RIGHT(N'00000' + CAST(ROW_NUMBER() OVER (ORDER BY i.ItemId) AS NVARCHAR(10)), 5),
               N'Receipt', i.ItemId, @WhGold, i.StockQty, i.UnitPrice, i.UnitPrice, CAST(SYSDATETIME() AS DATE),
               N'رسید اولیه ' + i.ItemTitle, N'Posted', N'seed', @SeedCompanyId
        FROM [inventory].[Items] i
        WHERE i.CompanyId = @SeedCompanyId AND i.IsDeleted = 0;

        INSERT INTO [inventory].[StockLayers] (ItemId, WarehouseId, SubWarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
        SELECT m.ItemId, m.WarehouseId, NULL, m.MovementId, m.Qty, m.CostPrice, m.MovementDate, m.CompanyId
        FROM [inventory].[Movements] m
        WHERE m.CompanyId = @SeedCompanyId AND m.Description LIKE N'%اولیه%';
    END

    -- تنظیمات انبار (روش میانگین موزون پیش‌فرض — بدون اتصال حسابداری تا تنظیم شود)
    IF NOT EXISTS (SELECT 1 FROM [inventory].[InventorySettings] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [inventory].[InventorySettings]
            (CompanyId, CostingMethod, DefaultWarehouseId, IsEnabled, UpdatedAt)
        VALUES
            (@SeedCompanyId, N'WeightedAverage', @WhGold, 0, SYSUTCDATETIME());
        -- IsEnabled=0 تا زمان پیکربندی حساب‌های انبار/مقابل؛ وگرنه ثبت فاکتورها با
        -- خطای «حساب‌ها تنظیم نشده» متوقف می‌شود (نگه‌داشته نمی‌شود — سند نادیده می‌ماند).
    END

    FETCH NEXT FROM inv_cursor INTO @SeedCompanyId;
END
CLOSE inv_cursor;
DEALLOCATE inv_cursor;