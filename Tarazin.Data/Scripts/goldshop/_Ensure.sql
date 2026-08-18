-- =============================================
-- Tarazin.Data/Scripts/goldshop/_Ensure.sql
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
        IsDeleted    BIT NOT NULL DEFAULT 0,
        UpdatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_GoldPrices_Items FOREIGN KEY (ItemCode) REFERENCES [goldshop].[GoldItems](ItemCode)
    );
END

-- Migration for databases created before soft-delete support.
IF COL_LENGTH(N'goldshop.GoldPrices', N'IsDeleted') IS NULL
    ALTER TABLE [goldshop].[GoldPrices] ADD IsDeleted BIT NOT NULL CONSTRAINT DF_GoldPrices_IsDeleted DEFAULT 0;

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

-- =============================================
-- Migrations: تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy
-- =============================================
IF COL_LENGTH(N'goldshop.GoldItems', N'UpdatedAt') IS NULL
    ALTER TABLE [goldshop].[GoldItems] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'goldshop.GoldItems', N'CreatedBy') IS NULL
    ALTER TABLE [goldshop].[GoldItems] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.GoldItems', N'UpdatedBy') IS NULL
    ALTER TABLE [goldshop].[GoldItems] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'goldshop.GoldPrices', N'CreatedAt') IS NULL
    ALTER TABLE [goldshop].[GoldPrices] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_GoldPrices_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'goldshop.GoldPrices', N'CreatedBy') IS NULL
    ALTER TABLE [goldshop].[GoldPrices] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.GoldPrices', N'UpdatedBy') IS NULL
    ALTER TABLE [goldshop].[GoldPrices] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'goldshop.SaleInvoices', N'UpdatedAt') IS NULL
    ALTER TABLE [goldshop].[SaleInvoices] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices', N'UpdatedBy') IS NULL
    ALTER TABLE [goldshop].[SaleInvoices] ADD UpdatedBy NVARCHAR(100) NULL;

-- Migration: اتصال فاکتور فروش به شعبه (ماژول branch — BI §86).
IF COL_LENGTH(N'goldshop.SaleInvoices', N'BranchId') IS NULL
    ALTER TABLE [goldshop].[SaleInvoices] ADD BranchId INT NULL;

IF COL_LENGTH(N'goldshop.InventorySnapshot', N'UpdatedAt') IS NULL
    ALTER TABLE [goldshop].[InventorySnapshot] ADD UpdatedAt DATETIME2 NULL;

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: GoldItems per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'goldshop.GoldItems', N'CompanyId') IS NULL
    ALTER TABLE [goldshop].[GoldItems] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_GoldItems_Company')
    ALTER TABLE [goldshop].[GoldItems] WITH CHECK ADD CONSTRAINT FK_GoldItems_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [goldshop].[GoldItems] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_GoldItems INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_GoldItems IS NOT NULL
        UPDATE [goldshop].[GoldItems] SET CompanyId = @DefaultCompanyId_GoldItems WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_GoldItems_Company' AND object_id = OBJECT_ID(N'[goldshop].[GoldItems]'))
    CREATE INDEX IX_GoldItems_Company ON [goldshop].[GoldItems](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: GoldPrices per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'goldshop.GoldPrices', N'CompanyId') IS NULL
    ALTER TABLE [goldshop].[GoldPrices] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_GoldPrices_Company')
    ALTER TABLE [goldshop].[GoldPrices] WITH CHECK ADD CONSTRAINT FK_GoldPrices_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [goldshop].[GoldPrices] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_GoldPrices INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_GoldPrices IS NOT NULL
        UPDATE [goldshop].[GoldPrices] SET CompanyId = @DefaultCompanyId_GoldPrices WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_GoldPrices_Company' AND object_id = OBJECT_ID(N'[goldshop].[GoldPrices]'))
    CREATE INDEX IX_GoldPrices_Company ON [goldshop].[GoldPrices](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: SaleInvoices per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'goldshop.SaleInvoices', N'CompanyId') IS NULL
    ALTER TABLE [goldshop].[SaleInvoices] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SaleInvoices_Company')
    ALTER TABLE [goldshop].[SaleInvoices] WITH CHECK ADD CONSTRAINT FK_SaleInvoices_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_SaleInvoices INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_SaleInvoices IS NOT NULL
        UPDATE [goldshop].[SaleInvoices] SET CompanyId = @DefaultCompanyId_SaleInvoices WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SaleInvoices_Company' AND object_id = OBJECT_ID(N'[goldshop].[SaleInvoices]'))
    CREATE INDEX IX_SaleInvoices_Company ON [goldshop].[SaleInvoices](CompanyId) WHERE CompanyId IS NOT NULL;
GO
