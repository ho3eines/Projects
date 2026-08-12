-- =============================================
-- HermesApp/Data/Scripts/goldshop/_Ensure.sql
-- Schema: goldshop (مدیریت طلافروشی)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'goldshop')
    EXEC(N'CREATE SCHEMA [goldshop]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'goldshop' AND t.name = N'GoldItems')
BEGIN
    CREATE TABLE [goldshop].[GoldItems] (
        GoldItemId  INT IDENTITY(1,1) PRIMARY KEY,
        ItemCode    NVARCHAR(50) NOT NULL UNIQUE,       -- XAU-24 | SIKKEH-EMAMI | ...
        Title       NVARCHAR(200) NOT NULL,
        Purity      DECIMAL(5,2) NULL,                  -- عیار
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Contract: GoldPrice (owner: goldshop).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'goldshop' AND t.name = N'GoldPrices')
BEGIN
    CREATE TABLE [goldshop].[GoldPrices] (
        PriceId      INT IDENTITY(1,1) PRIMARY KEY,
        ItemCode     NVARCHAR(50) NOT NULL UNIQUE,
        Title        NVARCHAR(200) NOT NULL,
        PricePerGram DECIMAL(18,0) NOT NULL DEFAULT 0,
        RateToIRR    DECIMAL(18,0) NULL,
        UpdatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_GoldPrices_Items FOREIGN KEY (ItemCode) REFERENCES [goldshop].[GoldItems](ItemCode)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'goldshop' AND t.name = N'SaleInvoices')
BEGIN
    CREATE TABLE [goldshop].[SaleInvoices] (
        InvoiceId      INT IDENTITY(1,1) PRIMARY KEY,
        InvoiceNumber  NVARCHAR(50) NOT NULL,
        InvoiceDate    DATE NOT NULL,
        CustomerName   NVARCHAR(200) NULL,
        ItemCode       NVARCHAR(50) NOT NULL,
        WeightGram     DECIMAL(18,3) NOT NULL DEFAULT 0,
        Workmanship    DECIMAL(18,0) NOT NULL DEFAULT 0,   -- اجرت
        Profit         DECIMAL(18,0) NOT NULL DEFAULT 0,   -- سود
        Tax            DECIMAL(18,0) NOT NULL DEFAULT 0,   -- مالیات (TaxRules-driven)
        TotalAmount    DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status         NVARCHAR(30) NOT NULL DEFAULT N'Issued',
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy      NVARCHAR(100) NULL
    );
    CREATE INDEX IX_SaleInvoices_Date ON [goldshop].[SaleInvoices](InvoiceDate);
END

-- Consumer read-model: inventory snapshot (InventoryMovement consumer).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'goldshop' AND t.name = N'InventorySnapshot')
BEGIN
    CREATE TABLE [goldshop].[InventorySnapshot] (
        SnapshotId    INT IDENTITY(1,1) PRIMARY KEY,
        MovementId    INT NOT NULL UNIQUE,
        ItemCode      NVARCHAR(50) NOT NULL,
        MovementType  NVARCHAR(30) NOT NULL,
        Qty           DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitPrice     DECIMAL(18,2) NOT NULL DEFAULT 0,
        MovementDate  DATE NOT NULL,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Event backbone (ADR-002).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'goldshop' AND t.name = N'Outbox')
BEGIN
    CREATE TABLE [goldshop].[Outbox] (
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
    CREATE INDEX IX_Outbox_Ready ON [goldshop].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
END
