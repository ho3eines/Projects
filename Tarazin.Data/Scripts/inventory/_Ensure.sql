-- =============================================
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
