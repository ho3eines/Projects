-- =============================================
-- webapi/Data/Scripts/accounting/_Ensure.sql
-- Schema: accounting
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'accounting')
    EXEC(N'CREATE SCHEMA [accounting]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'Documents')
BEGIN
    CREATE TABLE [accounting].[Documents] (
        DocumentId        INT IDENTITY(1,1) PRIMARY KEY,
        DocumentNumber    NVARCHAR(50) NOT NULL,
        DocumentDate      DATE NOT NULL,
        DocumentType      NVARCHAR(50) NULL,
        CounterPartyName  NVARCHAR(200) NULL,
        TotalAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyCode      NVARCHAR(10) NULL,
        Status            NVARCHAR(50) NOT NULL DEFAULT N'Draft',
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        IsDeleted         BIT NOT NULL DEFAULT 0
    );
END

-- Contract: ChartOfAccount (owner: accounting).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'ChartOfAccounts')
BEGIN
    CREATE TABLE [accounting].[ChartOfAccounts] (
        AccountId       INT IDENTITY(1,1) PRIMARY KEY,
        AccountCode     NVARCHAR(30) NOT NULL UNIQUE,
        Title           NVARCHAR(200) NOT NULL,
        AccountType     NVARCHAR(30) NULL,              -- Asset | Liability | Equity | Income | Expense
        ParentAccountId INT NULL,
        IsActive        BIT NOT NULL DEFAULT 1,
        IsDeleted       BIT NOT NULL DEFAULT 0,
        CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2 NULL
    );
END

-- Contract: TaxRule (owner: accounting) — config-driven Persian tax engine (PRD §8).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'TaxRules')
BEGIN
    CREATE TABLE [accounting].[TaxRules] (
        TaxRuleId     INT IDENTITY(1,1) PRIMARY KEY,
        RuleCode      NVARCHAR(50) NOT NULL UNIQUE,
        Title         NVARCHAR(200) NOT NULL,
        Category      NVARCHAR(50) NULL,                -- Vat | Payroll | Gold | Commerce
        RatePercent   DECIMAL(9,4) NOT NULL DEFAULT 0,
        EffectiveFrom DATE NOT NULL,
        IsActive      BIT NOT NULL DEFAULT 1,
        IsDeleted     BIT NOT NULL DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL
    );
END

-- Consumer read-model: sales invoices created from store orders (PRD §4).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'SalesInvoices')
BEGIN
    CREATE TABLE [accounting].[SalesInvoices] (
        InvoiceId      INT IDENTITY(1,1) PRIMARY KEY,
        InvoiceNumber  NVARCHAR(50) NOT NULL,
        OrderId        INT NOT NULL UNIQUE,             -- idempotency key (one invoice per order)
        CustomerName   NVARCHAR(200) NULL,
        TotalAmount    DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyCode   NVARCHAR(10) NULL,
        Status         NVARCHAR(30) NOT NULL DEFAULT N'Issued',
        InvoiceDate    DATE NOT NULL,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Consumer read-model: payroll GL postings (PRD §4 dual-write).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'PayrollPostings')
BEGIN
    CREATE TABLE [accounting].[PayrollPostings] (
        PostingId      INT IDENTITY(1,1) PRIMARY KEY,
        RunId          INT NOT NULL UNIQUE,             -- idempotency key
        Period         NVARCHAR(20) NOT NULL,
        EmployeeCount  INT NOT NULL DEFAULT 0,
        NetTotal       DECIMAL(18,2) NOT NULL DEFAULT 0,
        PostingDate    DATE NOT NULL,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Consumer read-model: inventory movement ledger (PRD §4 / contract InventoryMovement).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'InventoryLedger')
BEGIN
    CREATE TABLE [accounting].[InventoryLedger] (
        LedgerId      INT IDENTITY(1,1) PRIMARY KEY,
        MovementId    INT NOT NULL UNIQUE,
        ItemCode      NVARCHAR(50) NOT NULL,
        MovementType  NVARCHAR(30) NOT NULL,
        Qty           DECIMAL(18,3) NOT NULL DEFAULT 0,
        UnitPrice     DECIMAL(18,2) NOT NULL DEFAULT 0,
        MovementDate  DATE NOT NULL,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Consumer read-model: gold price snapshot (PRD §4 pub/sub).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'GoldPriceSnapshot')
BEGIN
    CREATE TABLE [accounting].[GoldPriceSnapshot] (
        SnapshotId    INT IDENTITY(1,1) PRIMARY KEY,
        ItemCode      NVARCHAR(50) NOT NULL UNIQUE,
        PricePerGram  DECIMAL(18,0) NOT NULL DEFAULT 0,
        UpdatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Event backbone (ADR-002): same shape in every product schema.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'Outbox')
BEGIN
    CREATE TABLE [accounting].[Outbox] (
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
    CREATE INDEX IX_Outbox_Ready ON [accounting].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
END
