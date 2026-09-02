-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/inventory/_Ensure.sql
-- Schema: inventory (انبار آمل)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'inventory')
    EXEC(N'CREATE SCHEMA [inventory]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Warehouses')
BEGIN
    CREATE TABLE [inventory].[Warehouses] (
        WarehouseId   INT IDENTITY(1,1) PRIMARY KEY,
        WarehouseCode NVARCHAR(30) NOT NULL,
        Title         NVARCHAR(120) NOT NULL,
        Location      NVARCHAR(200) NULL,
        IsActive      BIT NOT NULL DEFAULT 1,
        IsDeleted     BIT NOT NULL DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL,
        CreatedBy     NVARCHAR(120) NULL,
        UpdatedBy     NVARCHAR(120) NULL,
        CompanyId     INT NOT NULL
    );
    -- انبارها همیشه متعلق به یک شرکت مالی هستند؛ کد انبار فقط درون همان شرکت یکتا است.
    CREATE UNIQUE INDEX UX_Warehouses_Company_Code ON [inventory].[Warehouses] (CompanyId, WarehouseCode);
    CREATE INDEX IX_Warehouses_Company ON [inventory].[Warehouses] (CompanyId);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Items')
BEGIN
    CREATE TABLE [inventory].[Items] (
        ItemId      INT IDENTITY(1,1) PRIMARY KEY,
        ItemCode    NVARCHAR(50) NOT NULL UNIQUE,
        ItemTitle   NVARCHAR(200) NOT NULL,
        Category    NVARCHAR(80) NULL,
        Unit        NVARCHAR(20) NOT NULL DEFAULT N'عدد',
        StockQty    DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitPrice   DECIMAL(18,2) NOT NULL DEFAULT 0,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Movements')
BEGIN
    CREATE TABLE [inventory].[Movements] (
        MovementId     INT IDENTITY(1,1) PRIMARY KEY,
        MovementNumber NVARCHAR(50) NOT NULL,
        MovementType   NVARCHAR(30) NOT NULL,          -- Receipt | Issue | Adjustment
        ItemId         INT NOT NULL,
        WarehouseId    INT NULL,
        Qty            DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitPrice      DECIMAL(18,2) NOT NULL DEFAULT 0,
        MovementDate   DATE NOT NULL,
        Description    NVARCHAR(300) NULL,
        Status         NVARCHAR(30) NOT NULL DEFAULT N'Posted',
        IsDeleted      BIT NOT NULL DEFAULT 0,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy      NVARCHAR(100) NULL,
        SourceReference NVARCHAR(120) NULL,               -- PINV:id | SINV:id | StoreOrder:id | Transfer:id | Return:id | Stocktake | Manual
        CONSTRAINT FK_Movements_Items FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId)
    );
    CREATE INDEX IX_Movements_Date ON [inventory].[Movements](MovementDate, IsDeleted);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Reservations')
BEGIN
    CREATE TABLE [inventory].[Reservations] (
        ReservationId INT IDENTITY(1,1) PRIMARY KEY,
        ItemCode      NVARCHAR(50) NOT NULL,
        Qty           DECIMAL(18,3) NOT NULL DEFAULT 0,
        OrderId       INT NOT NULL,
        Status        NVARCHAR(30) NOT NULL DEFAULT N'Active',   -- Active | Released
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ReleasedAt    DATETIME2 NULL
    );
    CREATE INDEX IX_Reservations_Item ON [inventory].[Reservations](ItemCode, Status);
    CREATE INDEX IX_Reservations_Order ON [inventory].[Reservations](OrderId);
END

-- گروه‌های کالا (جدول پایه — انتخاب از داخل فرم کالا).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'ItemGroups')
BEGIN
    CREATE TABLE [inventory].[ItemGroups] (
        GroupId     INT IDENTITY(1,1) PRIMARY KEY,
        GroupCode   NVARCHAR(50) NOT NULL,
        Title       NVARCHAR(200) NOT NULL,
        SortOrder   INT NOT NULL DEFAULT 0,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL,
        UpdatedBy   NVARCHAR(100) NULL
    );
END

-- واحدهای کالا (جدول پایه — انتخاب از داخل فرم کالا).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Units')
BEGIN
    CREATE TABLE [inventory].[Units] (
        UnitId      INT IDENTITY(1,1) PRIMARY KEY,
        UnitCode    NVARCHAR(30) NOT NULL,
        Title       NVARCHAR(100) NOT NULL,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL,
        UpdatedBy   NVARCHAR(100) NULL
    );
END

-- انبارک‌ها (زیرمجموعهٔ انبار): کالاها یکسان ولی اسناد/گزارشات مجزا.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'SubWarehouses')
BEGIN
    CREATE TABLE [inventory].[SubWarehouses] (
        SubWarehouseId   INT IDENTITY(1,1) PRIMARY KEY,
        WarehouseId      INT NOT NULL,
        SubWarehouseCode NVARCHAR(50) NOT NULL,
        Title            NVARCHAR(120) NOT NULL,
        Location         NVARCHAR(200) NULL,
        IsActive         BIT NOT NULL DEFAULT 1,
        IsDeleted        BIT NOT NULL DEFAULT 0,
        CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt        DATETIME2 NULL,
        CreatedBy        NVARCHAR(100) NULL,
        UpdatedBy        NVARCHAR(100) NULL,
        CONSTRAINT FK_SubWarehouses_Warehouse FOREIGN KEY (WarehouseId) REFERENCES [inventory].[Warehouses](WarehouseId)
    );
END

-- لایه‌های موجودی (برای قیمت‌گذاری FIFO/LIFO/میانگین موزون).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'StockLayers')
BEGIN
    CREATE TABLE [inventory].[StockLayers] (
        LayerId           INT IDENTITY(1,1) PRIMARY KEY,
        ItemId            INT NOT NULL,
        WarehouseId       INT NOT NULL,
        SubWarehouseId    INT NULL,
        ReceiptMovementId INT NOT NULL,
        QtyRemaining      DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitCost          DECIMAL(18,2) NOT NULL DEFAULT 0,
        ReceivedDate      DATE NOT NULL,
        CompanyId         INT NULL,
        CONSTRAINT FK_StockLayers_Items FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId),
        CONSTRAINT FK_StockLayers_Movements FOREIGN KEY (ReceiptMovementId) REFERENCES [inventory].[Movements](MovementId)
    );
    CREATE INDEX IX_StockLayers_Item ON [inventory].[StockLayers](ItemId, WarehouseId, SubWarehouseId, ReceivedDate, LayerId);
END

-- تنظیمات انبار: روش قیمت‌گذاری + اتصال به حساب انبار (حسابداری).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'InventorySettings')
BEGIN
    CREATE TABLE [inventory].[InventorySettings] (
        CompanyId                INT NOT NULL PRIMARY KEY,
        CostingMethod            NVARCHAR(30) NOT NULL DEFAULT N'WeightedAverage',  -- WeightedAverage | FIFO | LIFO
        InventoryAccountId       INT NULL,
        InventoryAccountCode     NVARCHAR(4000) NULL,
        InventoryAccountTitle    NVARCHAR(200) NULL,
        ReceiptContraAccountId   INT NULL,
        ReceiptContraAccountCode NVARCHAR(4000) NULL,
        ReceiptContraAccountTitle NVARCHAR(200) NULL,
        IssueContraAccountId     INT NULL,
        IssueContraAccountCode   NVARCHAR(4000) NULL,
        IssueContraAccountTitle  NVARCHAR(200) NULL,
        DefaultWarehouseId       INT NULL,
        DefaultSubWarehouseId    INT NULL,
        IsEnabled                BIT NOT NULL DEFAULT 1,
        UpdatedAt                DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedBy                NVARCHAR(100) NULL,
        CONSTRAINT FK_InventorySettings_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END

-- Event backbone (ADR-002).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Outbox')
BEGIN
    CREATE TABLE [inventory].[Outbox] (
        OutboxId       BIGINT IDENTITY(1,1) PRIMARY KEY,
        EventType      NVARCHAR(100) NOT NULL,
        EventKey       NVARCHAR(200) NOT NULL,
        Payload        NVARCHAR(MAX) NOT NULL,
        PayloadVersion INT NOT NULL DEFAULT 1,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ProcessedAt    DATETIME2 NULL,
        Attempts       INT NOT NULL DEFAULT 0,
        LastError      NVARCHAR(MAX) NULL
    );
    CREATE INDEX IX_Outbox_Ready ON [inventory].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
END

-- =============================================
-- Migrations: تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy
-- =============================================
IF COL_LENGTH(N'inventory.Warehouses', N'UpdatedAt') IS NULL
    ALTER TABLE [inventory].[Warehouses] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'inventory.Warehouses', N'CreatedBy') IS NULL
    ALTER TABLE [inventory].[Warehouses] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'inventory.Warehouses', N'UpdatedBy') IS NULL
    ALTER TABLE [inventory].[Warehouses] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'inventory.Items', N'CreatedBy') IS NULL
    ALTER TABLE [inventory].[Items] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'inventory.Items', N'UpdatedBy') IS NULL
    ALTER TABLE [inventory].[Items] ADD UpdatedBy NVARCHAR(100) NULL;

-- Movements: نشانگر مبدأ (PINV/SINV/StoreOrder/Transfer/Return/Stocktake/Manual) برای تفکیک کانال در گزارشات.
IF COL_LENGTH(N'inventory.Movements', N'SourceReference') IS NULL
    ALTER TABLE [inventory].[Movements] ADD SourceReference NVARCHAR(120) NULL;

-- LotSerials: سریال/بچ/انقضای کالاها — در خرید ثبت (In) و در فروش/حواله صادر (Out) می‌شود.
IF OBJECT_ID(N'inventory.LotSerials', N'U') IS NULL
    CREATE TABLE [inventory].[LotSerials] (
        LotSerialId        BIGINT IDENTITY(1,1) PRIMARY KEY,
        ItemId             INT NOT NULL,
        WarehouseId        INT NULL,
        SubWarehouseId     INT NULL,
        LotNo              NVARCHAR(50) NULL,
        SerialNo           NVARCHAR(100) NULL,
        ExpiryDate         DATE NULL,
        Qty                DECIMAL(18,3) NOT NULL DEFAULT 1,
        Status             NVARCHAR(20) NOT NULL DEFAULT N'In',   -- In | Out
        SourceReference    NVARCHAR(200) NULL,                     -- PINV:id | SINV:id
        ReceiptMovementId  INT NULL,
        IssueMovementId    INT NULL,
        CompanyId          INT NOT NULL,
        CreatedAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy          NVARCHAR(100) NULL
    );
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_LotSerials_Item_Status' AND object_id = OBJECT_ID(N'inventory.LotSerials'))
    CREATE INDEX IX_LotSerials_Item_Status ON [inventory].[LotSerials](ItemId, Status) INCLUDE (WarehouseId, Qty, SerialNo, LotNo);
GO

-- حساب مقابل تعدیل (انبارگردانی) — سند حسابداری مغایرت.
IF COL_LENGTH(N'inventory.InventorySettings', N'AdjustmentAccountId') IS NULL
    ALTER TABLE [inventory].[InventorySettings] ADD AdjustmentAccountId INT NULL;
IF COL_LENGTH(N'inventory.InventorySettings', N'AdjustmentAccountCode') IS NULL
    ALTER TABLE [inventory].[InventorySettings] ADD AdjustmentAccountCode NVARCHAR(4000) NULL;
IF COL_LENGTH(N'inventory.InventorySettings', N'AdjustmentAccountTitle') IS NULL
    ALTER TABLE [inventory].[InventorySettings] ADD AdjustmentAccountTitle NVARCHAR(200) NULL;

-- درمان داده‌های قدیمی: اگر حسابداری انبار «فعال» ولی حساب‌های انبار/مقابل تنظیم نشده‌اند
-- (وضعیت ناسازگاری که ثبت فاکتور خرید/فروش را با خطا متوقف می‌کرد)، IsEnabled را خاموش کن.
-- کاربر پس از پیکربندی حساب‌ها در تنظیمات انبار آن را دوباره فعال می‌کند.
UPDATE [inventory].[InventorySettings]
SET IsEnabled = 0
WHERE IsEnabled = 1
  AND InventoryAccountId IS NULL
  AND ReceiptContraAccountId IS NULL
  AND IssueContraAccountId IS NULL;

-- گروه کالا / واحد کالا (ارجاع به جداول پایه جدید؛ فیلدهای متنی قدیمی نگه داشته می‌شوند).
IF COL_LENGTH(N'inventory.Items', N'GroupId') IS NULL
    ALTER TABLE [inventory].[Items] ADD GroupId INT NULL;
IF COL_LENGTH(N'inventory.Items', N'UnitId') IS NULL
    ALTER TABLE [inventory].[Items] ADD UnitId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Items_ItemGroups')
    ALTER TABLE [inventory].[Items] WITH CHECK ADD CONSTRAINT FK_Items_ItemGroups FOREIGN KEY (GroupId) REFERENCES [inventory].[ItemGroups](GroupId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Items_Units')
    ALTER TABLE [inventory].[Items] WITH CHECK ADD CONSTRAINT FK_Items_Units FOREIGN KEY (UnitId) REFERENCES [inventory].[Units](UnitId);
GO

IF COL_LENGTH(N'inventory.Movements', N'UpdatedAt') IS NULL
    ALTER TABLE [inventory].[Movements] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'inventory.Movements', N'UpdatedBy') IS NULL
    ALTER TABLE [inventory].[Movements] ADD UpdatedBy NVARCHAR(100) NULL;

-- انبارک / قیمت تمام‌شدهٔ حرکت (برای کاردکس و ارزش‌گذاری موجودی).
IF COL_LENGTH(N'inventory.Movements', N'SubWarehouseId') IS NULL
    ALTER TABLE [inventory].[Movements] ADD SubWarehouseId INT NULL;
IF COL_LENGTH(N'inventory.Movements', N'CostPrice') IS NULL
    ALTER TABLE [inventory].[Movements] ADD CostPrice DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Movements_SubWarehouses')
    ALTER TABLE [inventory].[Movements] WITH CHECK ADD CONSTRAINT FK_Movements_SubWarehouses FOREIGN KEY (SubWarehouseId) REFERENCES [inventory].[SubWarehouses](SubWarehouseId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Movements_Warehouse' AND object_id = OBJECT_ID(N'[inventory].[Movements]'))
    CREATE INDEX IX_Movements_Warehouse ON [inventory].[Movements](WarehouseId, SubWarehouseId);
GO

IF COL_LENGTH(N'inventory.Reservations', N'UpdatedAt') IS NULL
    ALTER TABLE [inventory].[Reservations] ADD UpdatedAt DATETIME2 NULL;

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: ItemGroups / Units per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'inventory.ItemGroups', N'CompanyId') IS NULL
    ALTER TABLE [inventory].[ItemGroups] ADD CompanyId INT NULL;
GO
IF EXISTS (SELECT 1 FROM [inventory].[ItemGroups] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_ItemGroups INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_ItemGroups IS NOT NULL
        UPDATE [inventory].[ItemGroups] SET CompanyId = @DefaultCompanyId_ItemGroups WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ItemGroups_Company' AND object_id = OBJECT_ID(N'inventory.ItemGroups'))
    CREATE INDEX IX_ItemGroups_Company ON [inventory].[ItemGroups](CompanyId) WHERE CompanyId IS NOT NULL;
GO

IF COL_LENGTH(N'inventory.Units', N'CompanyId') IS NULL
    ALTER TABLE [inventory].[Units] ADD CompanyId INT NULL;
GO
IF EXISTS (SELECT 1 FROM [inventory].[Units] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Units INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Units IS NOT NULL
        UPDATE [inventory].[Units] SET CompanyId = @DefaultCompanyId_Units WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Units_Company' AND object_id = OBJECT_ID(N'inventory.Units'))
    CREATE INDEX IX_Units_Company ON [inventory].[Units](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Warehouses per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'inventory.Warehouses', N'CompanyId') IS NULL
    ALTER TABLE [inventory].[Warehouses] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Warehouses_Company')
    ALTER TABLE [inventory].[Warehouses] WITH CHECK ADD CONSTRAINT FK_Warehouses_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [inventory].[Warehouses] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Warehouses INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Warehouses IS NOT NULL
        UPDATE [inventory].[Warehouses] SET CompanyId = @DefaultCompanyId_Warehouses WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Warehouses_Company' AND object_id = OBJECT_ID(N'[inventory].[Warehouses]'))
    CREATE INDEX IX_Warehouses_Company ON [inventory].[Warehouses](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- مهاجرت یکتایی کد انبار از «سراسری» به «درون‌شرکتی» (مثل BaseCol):
-- CREATE TABLE قدیمی WarehouseCode را UNIQUE سراسری می‌کرد که با قانون
-- چندشرکتی ناسازگار بود. قید خودکار قدیمی حذف و ایندکس یکتای فیلترشده جایگزین می‌شود.
DECLARE @WarehouseCodeUq NVARCHAR(128) = NULL;
SELECT @WarehouseCodeUq = kc.name
FROM sys.key_constraints kc
CROSS APPLY (
    SELECT COUNT(*) AS ColCount, MAX(c.name) AS LastCol
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
) cols
WHERE kc.parent_object_id = OBJECT_ID(N'[inventory].[Warehouses]')
  AND kc.type = N'UQ'
  AND cols.ColCount = 1
  AND cols.LastCol = N'WarehouseCode';
IF @WarehouseCodeUq IS NOT NULL
BEGIN
    DECLARE @dropWhUqSql NVARCHAR(400) =
        N'ALTER TABLE [inventory].[Warehouses] DROP CONSTRAINT ' + QUOTENAME(@WarehouseCodeUq) + N';';
    EXEC sp_executesql @dropWhUqSql;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Warehouses_Company_Code' AND object_id = OBJECT_ID(N'[inventory].[Warehouses]'))
    CREATE UNIQUE INDEX UX_Warehouses_Company_Code
        ON [inventory].[Warehouses](CompanyId, WarehouseCode)
        WHERE IsDeleted = 0 AND CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Items per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'inventory.Items', N'CompanyId') IS NULL
    ALTER TABLE [inventory].[Items] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Items_Company')
    ALTER TABLE [inventory].[Items] WITH CHECK ADD CONSTRAINT FK_Items_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Items INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Items IS NOT NULL
        UPDATE [inventory].[Items] SET CompanyId = @DefaultCompanyId_Items WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Items_Company' AND object_id = OBJECT_ID(N'[inventory].[Items]'))
    CREATE INDEX IX_Items_Company ON [inventory].[Items](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- مهاجرت یکتایی کد کالا از «سراسری» به «درون‌شرکتی» (مثل WarehouseCode):
DECLARE @ItemCodeUq NVARCHAR(128) = NULL;
SELECT @ItemCodeUq = kc.name
FROM sys.key_constraints kc
CROSS APPLY (
    SELECT COUNT(*) AS ColCount, MAX(c.name) AS LastCol
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
) cols
WHERE kc.parent_object_id = OBJECT_ID(N'[inventory].[Items]')
  AND kc.type = N'UQ'
  AND cols.ColCount = 1
  AND cols.LastCol = N'ItemCode';
IF @ItemCodeUq IS NOT NULL
BEGIN
    DECLARE @dropItemUqSql NVARCHAR(400) =
        N'ALTER TABLE [inventory].[Items] DROP CONSTRAINT ' + QUOTENAME(@ItemCodeUq) + N';';
    EXEC sp_executesql @dropItemUqSql;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Items_Company_Code' AND object_id = OBJECT_ID(N'[inventory].[Items]'))
    CREATE UNIQUE INDEX UX_Items_Company_Code
        ON [inventory].[Items](CompanyId, ItemCode)
        WHERE IsDeleted = 0 AND CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Movements per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'inventory.Movements', N'CompanyId') IS NULL
    ALTER TABLE [inventory].[Movements] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Movements_Company')
    ALTER TABLE [inventory].[Movements] WITH CHECK ADD CONSTRAINT FK_Movements_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [inventory].[Movements] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Movements INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Movements IS NOT NULL
        UPDATE [inventory].[Movements] SET CompanyId = @DefaultCompanyId_Movements WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Movements_Company' AND object_id = OBJECT_ID(N'[inventory].[Movements]'))
    CREATE INDEX IX_Movements_Company ON [inventory].[Movements](CompanyId) WHERE CompanyId IS NOT NULL;
GO
-- =============================================
-- Tarazin.Data/Scripts/inventory/_EnsurePhase1.sql
-- Schema: inventory, store
-- Endpoint: execute (startup)
-- Phase 1: Items enrichment + PurchaseInvoices + SalesInvoices + Returns + Transfers + Barcodes
-- Idempotent — safe to re-run; never drops existing data.
-- =============================================

-- ─────────────────────────────────────────────
-- 1. Items: enrich with SKU, Barcode, Brand, Model, MinStock, MaxStock, ReorderPoint, Batch/Serial/Expiry
-- ─────────────────────────────────────────────
IF COL_LENGTH(N'inventory.Items', N'SKU') IS NULL
    ALTER TABLE [inventory].[Items] ADD SKU NVARCHAR(100) NULL;
IF COL_LENGTH(N'inventory.Items', N'Barcode') IS NULL
    ALTER TABLE [inventory].[Items] ADD Barcode NVARCHAR(100) NULL;
IF COL_LENGTH(N'inventory.Items', N'Brand') IS NULL
    ALTER TABLE [inventory].[Items] ADD Brand NVARCHAR(100) NULL;
IF COL_LENGTH(N'inventory.Items', N'Model') IS NULL
    ALTER TABLE [inventory].[Items] ADD Model NVARCHAR(100) NULL;
IF COL_LENGTH(N'inventory.Items', N'MinStock') IS NULL
    ALTER TABLE [inventory].[Items] ADD MinStock DECIMAL(18,3) NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'MaxStock') IS NULL
    ALTER TABLE [inventory].[Items] ADD MaxStock DECIMAL(18,3) NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'ReorderPoint') IS NULL
    ALTER TABLE [inventory].[Items] ADD ReorderPoint DECIMAL(18,3) NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'HasBatch') IS NULL
    ALTER TABLE [inventory].[Items] ADD HasBatch BIT NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'HasSerial') IS NULL
    ALTER TABLE [inventory].[Items] ADD HasSerial BIT NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'HasExpiry') IS NULL
    ALTER TABLE [inventory].[Items] ADD HasExpiry BIT NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'LatinTitle') IS NULL
    ALTER TABLE [inventory].[Items] ADD LatinTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'inventory.Items', N'PurchasePrice') IS NULL
    ALTER TABLE [inventory].[Items] ADD PurchasePrice DECIMAL(18,2) NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'SalePrice') IS NULL
    ALTER TABLE [inventory].[Items] ADD SalePrice DECIMAL(18,2) NOT NULL DEFAULT 0;
IF COL_LENGTH(N'inventory.Items', N'Description') IS NULL
    ALTER TABLE [inventory].[Items] ADD Description NVARCHAR(500) NULL;
IF COL_LENGTH(N'inventory.Items', N'ImageUrl') IS NULL
    ALTER TABLE [inventory].[Items] ADD ImageUrl NVARCHAR(500) NULL;
GO

-- Index for barcode search
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Items_Barcode' AND object_id = OBJECT_ID(N'[inventory].[Items]'))
    CREATE INDEX IX_Items_Barcode ON [inventory].[Items](Barcode) WHERE Barcode IS NOT NULL AND IsDeleted = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Items_SKU' AND object_id = OBJECT_ID(N'[inventory].[Items]'))
    CREATE INDEX IX_Items_SKU ON [inventory].[Items](SKU) WHERE SKU IS NOT NULL AND IsDeleted = 0;
GO

-- ─────────────────────────────────────────────
-- 2. Barcodes (one item → many barcodes)
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Barcodes')
BEGIN
    CREATE TABLE [inventory].[Barcodes] (
        BarcodeId   INT IDENTITY(1,1) PRIMARY KEY,
        ItemId      INT NOT NULL,
        Barcode     NVARCHAR(100) NOT NULL,
        IsPrimary   BIT NOT NULL DEFAULT 0,
        IsActive    BIT NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Barcodes_Items FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId)
    );
    CREATE UNIQUE INDEX UX_Barcodes_Code ON [inventory].[Barcodes](Barcode) WHERE IsActive = 1;
    CREATE INDEX IX_Barcodes_Item ON [inventory].[Barcodes](ItemId);
END

-- ─────────────────────────────────────────────
-- 3. Invoices (فاکتور یکپارچه خرید/فروش — تفکیک با OperationType)
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'Invoices')
BEGIN
    CREATE TABLE [inventory].[Invoices] (
        InvoiceId         INT IDENTITY(1,1) PRIMARY KEY,
        OperationType     NVARCHAR(10) NOT NULL DEFAULT N'Purchase', -- Purchase | Sales
        InvoiceNumber     NVARCHAR(50) NOT NULL,
        InvoiceDate       DATE NOT NULL,
        SupplierPartyId   INT NULL,           -- خرید: تأمین‌کننده
        SupplierName      NVARCHAR(200) NULL,
        CustomerPartyId   INT NULL,           -- فروش: مشتری
        CustomerName      NVARCHAR(200) NULL,
        WarehouseId       INT NULL,
        SubWarehouseId    INT NULL,
        ReferenceNumber   NVARCHAR(100) NULL,
        PaymentTerms      NVARCHAR(50) NULL,  -- Cash | Credit
        DueDate           DATE NULL,
        SaleType          NVARCHAR(30) NULL,  -- Retail | Wholesale | Special (فقط فروش)
        Description       NVARCHAR(500) NULL,
        GrossAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        DiscountAmount    DECIMAL(18,2) NOT NULL DEFAULT 0,
        ChargesAmount     DECIMAL(18,2) NOT NULL DEFAULT 0,  -- freight, other charges
        TaxAmount         DECIMAL(18,2) NOT NULL DEFAULT 0,
        DutyAmount        DECIMAL(18,2) NOT NULL DEFAULT 0,   -- عوارض
        NetAmount         DECIMAL(18,2) NOT NULL DEFAULT 0,
        CostOfGoodsSold   DECIMAL(18,2) NOT NULL DEFAULT 0,   -- بهای تمام‌شده (فقط فروش)
        GrossProfit       DECIMAL(18,2) NOT NULL DEFAULT 0,   -- سود ناخالص (فقط فروش)
        Status            NVARCHAR(30) NOT NULL DEFAULT N'Draft', -- Draft | Pending | Approved | Posted | Cancelled
        DocumentId        INT NULL,           -- link to accounting.Documents
        CompanyId         INT NOT NULL,
        FiscalYearId      INT NULL,
        IsDeleted         BIT NOT NULL DEFAULT 0,
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        CONSTRAINT FK_Invoices_Warehouse FOREIGN KEY (WarehouseId) REFERENCES [inventory].[Warehouses](WarehouseId),
        CONSTRAINT FK_Invoices_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_Invoices_Type_Date ON [inventory].[Invoices](OperationType, InvoiceDate, IsDeleted);
    CREATE INDEX IX_Invoices_Company ON [inventory].[Invoices](CompanyId) WHERE IsDeleted = 0;
END
GO

-- ─────────────────────────────────────────────
-- 4. InvoiceLines (اقلام فاکتور یکپارچه)
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'InvoiceLines')
BEGIN
    CREATE TABLE [inventory].[InvoiceLines] (
        InvoiceLineId    INT IDENTITY(1,1) PRIMARY KEY,
        InvoiceId        INT NOT NULL,
        ItemId           INT NOT NULL,
        UnitId           INT NULL,
        Qty              DECIMAL(18,3) NOT NULL DEFAULT 0,
        GiftQty          DECIMAL(18,3) NOT NULL DEFAULT 0,  -- تعداد هدیه
        UnitPrice        DECIMAL(18,2) NOT NULL DEFAULT 0,
        GrossAmount      DECIMAL(18,2) NOT NULL DEFAULT 0,
        DiscountPercent  DECIMAL(5,2) NOT NULL DEFAULT 0,
        DiscountAmount   DECIMAL(18,2) NOT NULL DEFAULT 0,
        TaxPercent       DECIMAL(5,2) NOT NULL DEFAULT 0,
        TaxAmount        DECIMAL(18,2) NOT NULL DEFAULT 0,
        DutyPercent      DECIMAL(5,2) NOT NULL DEFAULT 0,
        DutyAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        ChargesAmount    DECIMAL(18,2) NOT NULL DEFAULT 0,  -- prorated freight/other
        CostPrice        DECIMAL(18,2) NOT NULL DEFAULT 0,  -- قیمت تمام‌شده قلم
        NetAmount        DECIMAL(18,2) NOT NULL DEFAULT 0,
        SortOrder        INT NOT NULL DEFAULT 0,
        CONSTRAINT FK_InvoiceLines_Invoice FOREIGN KEY (InvoiceId) REFERENCES [inventory].[Invoices](InvoiceId),
        CONSTRAINT FK_InvoiceLines_Item FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId)
    );
    CREATE INDEX IX_InvoiceLines_Invoice ON [inventory].[InvoiceLines](InvoiceId);
END
GO

-- ─────────────────────────────────────────────
-- 5. Migration: legacy split invoice tables → unified Invoices (یک‌بار اجرا)
-- ─────────────────────────────────────────────
IF OBJECT_ID(N'[inventory].[PurchaseInvoices]') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [inventory].[Invoices] WHERE OperationType = N'Purchase')
BEGIN
    -- Legacy tables carry mobile RLS policies (central.MobileCompanyPolicy_*) that
    -- block DROP TABLE. Drop those policies first; they are rebuilt by
    -- central._MobileSecurity.sql for the replacement tables on the next run.
    DECLARE @LegacyPolicyName SYSNAME;
    DECLARE legacy_policy_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT sp.name
        FROM sys.security_policies sp
        JOIN sys.security_predicates spred ON spred.object_id = sp.object_id
        WHERE OBJECT_NAME(spred.target_object_id) IN (
            N'PurchaseInvoices', N'PurchaseInvoiceLines',
            N'PurchaseReturns',  N'PurchaseReturnLines',
            N'SalesInvoices',    N'SalesInvoiceLines',
            N'SalesReturns',     N'SalesReturnLines');
    OPEN legacy_policy_cur;
    FETCH NEXT FROM legacy_policy_cur INTO @LegacyPolicyName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @DropPolicySql NVARCHAR(MAX) = N'DROP SECURITY POLICY [central].' + QUOTENAME(@LegacyPolicyName) + N';';
        EXEC sys.sp_executesql @DropPolicySql;
        FETCH NEXT FROM legacy_policy_cur INTO @LegacyPolicyName;
    END
    CLOSE legacy_policy_cur;
    DEALLOCATE legacy_policy_cur;

    -- legacy return tables reference legacy invoice tables — drop them first
    IF OBJECT_ID(N'[inventory].[PurchaseReturnLines]') IS NOT NULL DROP TABLE [inventory].[PurchaseReturnLines];
    IF OBJECT_ID(N'[inventory].[PurchaseReturns]') IS NOT NULL DROP TABLE [inventory].[PurchaseReturns];
    IF OBJECT_ID(N'[inventory].[SalesReturnLines]') IS NOT NULL DROP TABLE [inventory].[SalesReturnLines];
    IF OBJECT_ID(N'[inventory].[SalesReturns]') IS NOT NULL DROP TABLE [inventory].[SalesReturns];

    DECLARE @InvMap TABLE (OldId INT NOT NULL, NewId INT NOT NULL);

    -- خرید
    INSERT INTO [inventory].[Invoices]
        (OperationType, InvoiceNumber, InvoiceDate, SupplierPartyId, SupplierName,
         WarehouseId, SubWarehouseId, ReferenceNumber, PaymentTerms, DueDate, Description,
         GrossAmount, DiscountAmount, ChargesAmount, TaxAmount, DutyAmount, NetAmount,
         CostOfGoodsSold, GrossProfit, Status, DocumentId, CompanyId, FiscalYearId,
         IsDeleted, CreatedAt, UpdatedAt, CreatedBy, UpdatedBy)
    SELECT N'Purchase', InvoiceNumber, InvoiceDate, SupplierPartyId, SupplierName,
           WarehouseId, SubWarehouseId, ReferenceNumber, PaymentTerms, DueDate, Description,
           GrossAmount, DiscountAmount, ChargesAmount, TaxAmount, DutyAmount, NetAmount,
           0, 0, Status, DocumentId, CompanyId, FiscalYearId,
           IsDeleted, CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM [inventory].[PurchaseInvoices];

    INSERT INTO @InvMap (OldId, NewId)
    SELECT p.PurchaseInvoiceId, i.InvoiceId
    FROM [inventory].[PurchaseInvoices] p
    JOIN [inventory].[Invoices] i
      ON i.CompanyId = p.CompanyId AND i.InvoiceNumber = p.InvoiceNumber AND i.OperationType = N'Purchase';

    INSERT INTO [inventory].[InvoiceLines]
        (InvoiceId, ItemId, UnitId, Qty, GiftQty, UnitPrice, GrossAmount,
         DiscountPercent, DiscountAmount, TaxPercent, TaxAmount, DutyPercent, DutyAmount,
         ChargesAmount, CostPrice, NetAmount, SortOrder)
    SELECT m.NewId, l.ItemId, l.UnitId, l.Qty, l.GiftQty, l.UnitPrice, l.GrossAmount,
           l.DiscountPercent, l.DiscountAmount, l.TaxPercent, l.TaxAmount, l.DutyPercent, l.DutyAmount,
           l.ChargesAmount, l.CostPrice, l.NetAmount, l.SortOrder
    FROM [inventory].[PurchaseInvoiceLines] l
    JOIN @InvMap m ON m.OldId = l.PurchaseInvoiceId;

    DROP TABLE [inventory].[PurchaseInvoiceLines];
    DROP TABLE [inventory].[PurchaseInvoices];

    -- فروش
    DELETE FROM @InvMap;

    INSERT INTO [inventory].[Invoices]
        (OperationType, InvoiceNumber, InvoiceDate, SupplierPartyId, SupplierName,
         CustomerPartyId, CustomerName, WarehouseId, SubWarehouseId, ReferenceNumber,
         PaymentTerms, DueDate, SaleType, Description,
         GrossAmount, DiscountAmount, ChargesAmount, TaxAmount, DutyAmount, NetAmount,
         CostOfGoodsSold, GrossProfit, Status, DocumentId, CompanyId, FiscalYearId,
         IsDeleted, CreatedAt, UpdatedAt, CreatedBy, UpdatedBy)
    SELECT N'Sales', InvoiceNumber, InvoiceDate, NULL, NULL,
           CustomerPartyId, CustomerName, WarehouseId, SubWarehouseId, ReferenceNumber,
           PaymentTerms, DueDate, SaleType, Description,
           GrossAmount, DiscountAmount, ChargesAmount, TaxAmount, DutyAmount, NetAmount,
           CostOfGoodsSold, GrossProfit, Status, DocumentId, CompanyId, FiscalYearId,
           IsDeleted, CreatedAt, UpdatedAt, CreatedBy, UpdatedBy
    FROM [inventory].[SalesInvoices];

    INSERT INTO @InvMap (OldId, NewId)
    SELECT s.SalesInvoiceId, i.InvoiceId
    FROM [inventory].[SalesInvoices] s
    JOIN [inventory].[Invoices] i
      ON i.CompanyId = s.CompanyId AND i.InvoiceNumber = s.InvoiceNumber AND i.OperationType = N'Sales';

    INSERT INTO [inventory].[InvoiceLines]
        (InvoiceId, ItemId, UnitId, Qty, GiftQty, UnitPrice, GrossAmount,
         DiscountPercent, DiscountAmount, TaxPercent, TaxAmount, DutyPercent, DutyAmount,
         ChargesAmount, CostPrice, NetAmount, SortOrder)
    SELECT m.NewId, l.ItemId, l.UnitId, l.Qty, l.GiftQty, l.UnitPrice, l.GrossAmount,
           l.DiscountPercent, l.DiscountAmount, l.TaxPercent, l.TaxAmount, l.DutyPercent, l.DutyAmount,
           l.ChargesAmount, l.CostPrice, l.NetAmount, l.SortOrder
    FROM [inventory].[SalesInvoiceLines] l
    JOIN @InvMap m ON m.OldId = l.SalesInvoiceId;

    DROP TABLE [inventory].[SalesInvoiceLines];
    DROP TABLE [inventory].[SalesInvoices];
END
GO

-- ─────────────────────────────────────────────
-- 6. PurchaseReturns (برگشت خرید)
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'PurchaseReturns')
BEGIN
    CREATE TABLE [inventory].[PurchaseReturns] (
        PurchaseReturnId    INT IDENTITY(1,1) PRIMARY KEY,
        ReturnNumber        NVARCHAR(50) NOT NULL,
        ReturnDate          DATE NOT NULL,
        InvoiceId           INT NOT NULL,       -- original unified invoice (Purchase)
        WarehouseId         INT NULL,
        Description         NVARCHAR(500) NULL,
        TotalAmount         DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status              NVARCHAR(30) NOT NULL DEFAULT N'Draft',
        DocumentId          INT NULL,
        CompanyId           INT NOT NULL,
        FiscalYearId        INT NULL,
        IsDeleted           BIT NOT NULL DEFAULT 0,
        CreatedAt           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt           DATETIME2 NULL,
        CreatedBy           NVARCHAR(100) NULL,
        UpdatedBy           NVARCHAR(100) NULL,
        CONSTRAINT FK_PurchaseReturns_Invoice FOREIGN KEY (InvoiceId) REFERENCES [inventory].[Invoices](InvoiceId),
        CONSTRAINT FK_PurchaseReturns_Warehouse FOREIGN KEY (WarehouseId) REFERENCES [inventory].[Warehouses](WarehouseId),
        CONSTRAINT FK_PurchaseReturns_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_PurchaseReturns_Date ON [inventory].[PurchaseReturns](ReturnDate, IsDeleted);
END
GO

-- PurchaseReturnLines
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'PurchaseReturnLines')
BEGIN
    CREATE TABLE [inventory].[PurchaseReturnLines] (
        PurchaseReturnLineId INT IDENTITY(1,1) PRIMARY KEY,
        PurchaseReturnId     INT NOT NULL,
        InvoiceLineId        INT NOT NULL,       -- original line for returnable-qty check
        ItemId               INT NOT NULL,
        Qty                  DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitPrice            DECIMAL(18,2) NOT NULL DEFAULT 0,
        NetAmount            DECIMAL(18,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_PurchaseRetLines_Return FOREIGN KEY (PurchaseReturnId) REFERENCES [inventory].[PurchaseReturns](PurchaseReturnId),
        CONSTRAINT FK_PurchaseRetLines_InvLine FOREIGN KEY (InvoiceLineId) REFERENCES [inventory].[InvoiceLines](InvoiceLineId),
        CONSTRAINT FK_PurchaseRetLines_Item FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId)
    );
    CREATE INDEX IX_PurchaseRetLines_Return ON [inventory].[PurchaseReturnLines](PurchaseReturnId);
END
GO

-- ─────────────────────────────────────────────
-- 7. SalesReturns (برگشت فروش)
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'SalesReturns')
BEGIN
    CREATE TABLE [inventory].[SalesReturns] (
        SalesReturnId      INT IDENTITY(1,1) PRIMARY KEY,
        ReturnNumber       NVARCHAR(50) NOT NULL,
        ReturnDate         DATE NOT NULL,
        InvoiceId          INT NOT NULL,       -- original unified invoice (Sales)
        WarehouseId        INT NULL,
        Description        NVARCHAR(500) NULL,
        TotalAmount        DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status             NVARCHAR(30) NOT NULL DEFAULT N'Draft',
        DocumentId         INT NULL,
        CompanyId          INT NOT NULL,
        FiscalYearId       INT NULL,
        IsDeleted           BIT NOT NULL DEFAULT 0,
        CreatedAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt          DATETIME2 NULL,
        CreatedBy          NVARCHAR(100) NULL,
        UpdatedBy          NVARCHAR(100) NULL,
        CONSTRAINT FK_SalesReturns_Invoice FOREIGN KEY (InvoiceId) REFERENCES [inventory].[Invoices](InvoiceId),
        CONSTRAINT FK_SalesReturns_Warehouse FOREIGN KEY (WarehouseId) REFERENCES [inventory].[Warehouses](WarehouseId),
        CONSTRAINT FK_SalesReturns_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_SalesReturns_Date ON [inventory].[SalesReturns](ReturnDate, IsDeleted);
END
GO

-- SalesReturnLines
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'SalesReturnLines')
BEGIN
    CREATE TABLE [inventory].[SalesReturnLines] (
        SalesReturnLineId INT IDENTITY(1,1) PRIMARY KEY,
        SalesReturnId     INT NOT NULL,
        InvoiceLineId     INT NOT NULL,
        ItemId            INT NOT NULL,
        Qty               DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitPrice         DECIMAL(18,2) NOT NULL DEFAULT 0,
        NetAmount         DECIMAL(18,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_SalesRetLines_Return FOREIGN KEY (SalesReturnId) REFERENCES [inventory].[SalesReturns](SalesReturnId),
        CONSTRAINT FK_SalesRetLines_InvLine FOREIGN KEY (InvoiceLineId) REFERENCES [inventory].[InvoiceLines](InvoiceLineId),
        CONSTRAINT FK_SalesRetLines_Item FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId)
    );
    CREATE INDEX IX_SalesRetLines_Return ON [inventory].[SalesReturnLines](SalesReturnId);
END
GO
-- ─────────────────────────────────────────────
-- 9. WarehouseTransfers (انتقال بین انبارها)
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'WarehouseTransfers')
BEGIN
    CREATE TABLE [inventory].[WarehouseTransfers] (
        TransferId         INT IDENTITY(1,1) PRIMARY KEY,
        TransferNumber     NVARCHAR(50) NOT NULL,
        TransferDate       DATE NOT NULL,
        FromWarehouseId    INT NOT NULL,
        ToWarehouseId      INT NOT NULL,
        Description        NVARCHAR(500) NULL,
        Status             NVARCHAR(30) NOT NULL DEFAULT N'Draft', -- Draft | Approved | Posted | Cancelled
        DocumentId         INT NULL,
        CompanyId          INT NOT NULL,
        IsDeleted          BIT NOT NULL DEFAULT 0,
        CreatedAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt          DATETIME2 NULL,
        CreatedBy          NVARCHAR(100) NULL,
        UpdatedBy          NVARCHAR(100) NULL,
        CONSTRAINT FK_Transfers_FromWh FOREIGN KEY (FromWarehouseId) REFERENCES [inventory].[Warehouses](WarehouseId),
        CONSTRAINT FK_Transfers_ToWh FOREIGN KEY (ToWarehouseId) REFERENCES [inventory].[Warehouses](WarehouseId),
        CONSTRAINT FK_Transfers_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_Transfers_Date ON [inventory].[WarehouseTransfers](TransferDate, IsDeleted);
END
GO

-- TransferLines
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'TransferLines')
BEGIN
    CREATE TABLE [inventory].[TransferLines] (
        TransferLineId INT IDENTITY(1,1) PRIMARY KEY,
        TransferId     INT NOT NULL,
        ItemId         INT NOT NULL,
        Qty            DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitCost       DECIMAL(18,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_TransferLines_Transfer FOREIGN KEY (TransferId) REFERENCES [inventory].[WarehouseTransfers](TransferId),
        CONSTRAINT FK_TransferLines_Item FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId)
    );
    CREATE INDEX IX_TransferLines_Transfer ON [inventory].[TransferLines](TransferId);
END
GO

-- ─────────────────────────────────────────────
-- 10. Multi-company scoping for new tables
-- ─────────────────────────────────────────────
IF COL_LENGTH(N'inventory.Invoices', N'CompanyId') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Invoices_Company')
BEGIN
    ALTER TABLE [inventory].[Invoices] WITH CHECK ADD CONSTRAINT FK_Invoices_Company
        FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
END
GO


-- ─────────────────────────────────────────────
-- 11. ItemUnits — واحدهای چندگانهٔ هر کالا با ضریب تبدیل و واحد پیش‌فرض
-- ─────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'inventory' AND t.name = N'ItemUnits')
BEGIN
    CREATE TABLE [inventory].[ItemUnits] (
        ItemUnitId   INT IDENTITY(1,1) PRIMARY KEY,
        ItemId       INT NOT NULL,
        UnitId       INT NOT NULL,
        Factor       DECIMAL(18,4) NOT NULL DEFAULT 1,   -- ضریب تبدیل به واحد پایه (IsDefault=1)
        IsDefault    BIT NOT NULL DEFAULT 0,             -- دقیقاً یک واحد پیش‌فرض (عامل=1)
        IsDeleted    BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL,
        CreatedBy    NVARCHAR(100) NULL,
        UpdatedBy    NVARCHAR(100) NULL,
        CONSTRAINT UQ_ItemUnits_Item_Unit UNIQUE (ItemId, UnitId),
        CONSTRAINT FK_ItemUnits_Item FOREIGN KEY (ItemId) REFERENCES [inventory].[Items](ItemId),
        CONSTRAINT FK_ItemUnits_Unit FOREIGN KEY (UnitId) REFERENCES [inventory].[Units](UnitId)
    );
    CREATE INDEX IX_ItemUnits_Item ON [inventory].[ItemUnits](ItemId);
END
GO
