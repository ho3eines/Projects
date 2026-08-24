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
        WarehouseCode NVARCHAR(30) NOT NULL UNIQUE,
        Title         NVARCHAR(120) NOT NULL,
        Location      NVARCHAR(200) NULL,
        IsActive      BIT NOT NULL DEFAULT 1,
        IsDeleted     BIT NOT NULL DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
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

IF COL_LENGTH(N'inventory.Movements', N'UpdatedAt') IS NULL
    ALTER TABLE [inventory].[Movements] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'inventory.Movements', N'UpdatedBy') IS NULL
    ALTER TABLE [inventory].[Movements] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'inventory.Reservations', N'UpdatedAt') IS NULL
    ALTER TABLE [inventory].[Reservations] ADD UpdatedAt DATETIME2 NULL;

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
