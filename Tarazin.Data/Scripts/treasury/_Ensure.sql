-- =============================================
-- Tarazin.Data/Scripts/treasury/_Ensure.sql
-- Schema: treasury (خزانه‌داری)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'treasury')
    EXEC(N'CREATE SCHEMA [treasury]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'Banks')
BEGIN
    CREATE TABLE [treasury].[Banks] (
        BankId      INT IDENTITY(1,1) PRIMARY KEY,
        BankCode    NVARCHAR(30) NOT NULL UNIQUE,
        Title       NVARCHAR(120) NOT NULL,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'BankAccounts')
BEGIN
    CREATE TABLE [treasury].[BankAccounts] (
        AccountId   INT IDENTITY(1,1) PRIMARY KEY,
        AccountName NVARCHAR(120) NOT NULL,
        AccountNo   NVARCHAR(40) NOT NULL,
        BankId      INT NULL,
        Balance     DECIMAL(18,2) NOT NULL DEFAULT 0,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_BankAccounts_Banks FOREIGN KEY (BankId) REFERENCES [treasury].[Banks](BankId)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'CashBoxes')
BEGIN
    CREATE TABLE [treasury].[CashBoxes] (
        CashBoxId   INT IDENTITY(1,1) PRIMARY KEY,
        CashBoxCode NVARCHAR(30) NOT NULL UNIQUE,
        Title       NVARCHAR(120) NOT NULL,
        Balance     DECIMAL(18,2) NOT NULL DEFAULT 0,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Contract: CurrencyRate (owner: treasury).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'CurrencyRates')
BEGIN
    CREATE TABLE [treasury].[CurrencyRates] (
        RateId         INT IDENTITY(1,1) PRIMARY KEY,
        CurrencyCode   NVARCHAR(10) NOT NULL UNIQUE,
        CurrencyName   NVARCHAR(80) NOT NULL,
        RateToIRR      DECIMAL(18,0) NOT NULL DEFAULT 1,
        RateDate       DATE NOT NULL,
        IsDeleted      BIT NOT NULL DEFAULT 0,
        UpdatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Migration for databases created before soft-delete support.
IF COL_LENGTH(N'treasury.CurrencyRates', N'IsDeleted') IS NULL
    ALTER TABLE [treasury].[CurrencyRates] ADD IsDeleted BIT NOT NULL CONSTRAINT DF_CurrencyRates_IsDeleted DEFAULT 0;

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'CashMovements')
BEGIN
    CREATE TABLE [treasury].[CashMovements] (
        MovementId      INT IDENTITY(1,1) PRIMARY KEY,
        MovementNumber  NVARCHAR(50) NOT NULL,
        MovementDate    DATE NOT NULL,
        Direction       NVARCHAR(10) NOT NULL,           -- In | Out
        Amount          DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyCode    NVARCHAR(10) NOT NULL DEFAULT N'IRR',
        AccountId       INT NULL,                        -- bank account
        CashBoxId       INT NULL,                        -- cash box
        Description     NVARCHAR(300) NULL,
        SourceReference NVARCHAR(100) NULL,              -- idempotency key (Invoice:12, Payroll:3)
        Status          NVARCHAR(30) NOT NULL DEFAULT N'Posted',
        CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy       NVARCHAR(100) NULL
    );
    CREATE INDEX IX_CashMovements_Date ON [treasury].[CashMovements](MovementDate);
    -- SQL Server UNIQUE constraint treats NULL as a value and allows only ONE null.
    -- Manual receipts have no source key, so uniqueness must ignore empty/NULL.
    CREATE UNIQUE INDEX UX_CashMovements_SourceReference
        ON [treasury].[CashMovements](SourceReference)
        WHERE SourceReference IS NOT NULL AND SourceReference <> N'';
END

-- Existing databases: drop the auto-named UNIQUE constraint that rejects a second NULL.
IF OBJECT_ID(N'treasury.CashMovements', N'U') IS NOT NULL
BEGIN
    DECLARE @uqName SYSNAME;
    SELECT TOP (1) @uqName = kc.name
    FROM sys.key_constraints kc
    JOIN sys.tables t ON kc.parent_object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = kc.unique_index_id
    JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = ic.column_id
    WHERE s.name = N'treasury'
      AND t.name = N'CashMovements'
      AND kc.type = N'UQ'
      AND c.name = N'SourceReference';

    IF @uqName IS NOT NULL
        EXEC(N'ALTER TABLE [treasury].[CashMovements] DROP CONSTRAINT [' + @uqName + N']');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'UX_CashMovements_SourceReference'
          AND object_id = OBJECT_ID(N'treasury.CashMovements'))
    BEGIN
        CREATE UNIQUE INDEX UX_CashMovements_SourceReference
            ON [treasury].[CashMovements](SourceReference)
            WHERE SourceReference IS NOT NULL AND SourceReference <> N'';
    END
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'Cheques')
BEGIN
    CREATE TABLE [treasury].[Cheques] (
        ChequeId      INT IDENTITY(1,1) PRIMARY KEY,
        ChequeNumber  NVARCHAR(50) NOT NULL,
        BankId        INT NULL,
        Amount        DECIMAL(18,2) NOT NULL DEFAULT 0,
        DueDate       DATE NULL,
        Direction     NVARCHAR(10) NOT NULL DEFAULT N'In',  -- In (دریافتی) | Out (پرداختی)
        Status        NVARCHAR(30) NOT NULL DEFAULT N'Pending',
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Cheques_Banks FOREIGN KEY (BankId) REFERENCES [treasury].[Banks](BankId)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'DayCloses')
BEGIN
    CREATE TABLE [treasury].[DayCloses] (
        DayCloseId   INT IDENTITY(1,1) PRIMARY KEY,
        DayDate      DATE NOT NULL UNIQUE,
        CashTotal    DECIMAL(18,2) NOT NULL DEFAULT 0,
        BankTotal    DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(100) NULL
    );
END

-- Event backbone (ADR-002).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'Outbox')
BEGIN
    CREATE TABLE [treasury].[Outbox] (
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
    CREATE INDEX IX_Outbox_Ready ON [treasury].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
END

-- =============================================
-- Migrations: تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy
-- =============================================
IF COL_LENGTH(N'treasury.Banks', N'UpdatedAt') IS NULL
    ALTER TABLE [treasury].[Banks] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'treasury.Banks', N'CreatedBy') IS NULL
    ALTER TABLE [treasury].[Banks] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'treasury.Banks', N'UpdatedBy') IS NULL
    ALTER TABLE [treasury].[Banks] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'treasury.BankAccounts', N'UpdatedAt') IS NULL
    ALTER TABLE [treasury].[BankAccounts] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'treasury.BankAccounts', N'CreatedBy') IS NULL
    ALTER TABLE [treasury].[BankAccounts] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'treasury.BankAccounts', N'UpdatedBy') IS NULL
    ALTER TABLE [treasury].[BankAccounts] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'treasury.CashBoxes', N'UpdatedAt') IS NULL
    ALTER TABLE [treasury].[CashBoxes] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'treasury.CashBoxes', N'CreatedBy') IS NULL
    ALTER TABLE [treasury].[CashBoxes] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'treasury.CashBoxes', N'UpdatedBy') IS NULL
    ALTER TABLE [treasury].[CashBoxes] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'treasury.CurrencyRates', N'CreatedAt') IS NULL
    ALTER TABLE [treasury].[CurrencyRates] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_CurrencyRates_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'treasury.CurrencyRates', N'CreatedBy') IS NULL
    ALTER TABLE [treasury].[CurrencyRates] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'treasury.CurrencyRates', N'UpdatedBy') IS NULL
    ALTER TABLE [treasury].[CurrencyRates] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'treasury.CashMovements', N'UpdatedAt') IS NULL
    ALTER TABLE [treasury].[CashMovements] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'treasury.CashMovements', N'UpdatedBy') IS NULL
    ALTER TABLE [treasury].[CashMovements] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'treasury.Cheques', N'UpdatedAt') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'treasury.Cheques', N'CreatedBy') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'treasury.Cheques', N'UpdatedBy') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'treasury.DayCloses', N'UpdatedAt') IS NULL
    ALTER TABLE [treasury].[DayCloses] ADD UpdatedAt DATETIME2 NULL;
