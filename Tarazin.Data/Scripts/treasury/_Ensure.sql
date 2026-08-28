-- =============================================
-- Cross-schema: central
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
    BEGIN
        -- EXEC در T-SQL اجازهٔ الحاق رشته با + را درون پرانتز نمی‌دهد؛
        -- ابتدا دستور در یک متغیر ساخته و سپس اجرا می‌شود (Msg 102: Incorrect syntax near '+').
        DECLARE @dropTreasuryUqSql NVARCHAR(400) =
            N'ALTER TABLE [treasury].[CashMovements] DROP CONSTRAINT ' + QUOTENAME(@uqName);
        EXEC sp_executesql @dropTreasuryUqSql;
    END

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

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Banks per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.Banks', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[Banks] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Banks_Company')
    ALTER TABLE [treasury].[Banks] WITH CHECK ADD CONSTRAINT FK_Banks_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[Banks] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Banks INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Banks IS NOT NULL
        UPDATE [treasury].[Banks] SET CompanyId = @DefaultCompanyId_Banks WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Banks_Company' AND object_id = OBJECT_ID(N'[treasury].[Banks]'))
    CREATE INDEX IX_Banks_Company ON [treasury].[Banks](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: BankAccounts per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.BankAccounts', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[BankAccounts] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_BankAccounts_Company')
    ALTER TABLE [treasury].[BankAccounts] WITH CHECK ADD CONSTRAINT FK_BankAccounts_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[BankAccounts] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_BankAccounts INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_BankAccounts IS NOT NULL
        UPDATE [treasury].[BankAccounts] SET CompanyId = @DefaultCompanyId_BankAccounts WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BankAccounts_Company' AND object_id = OBJECT_ID(N'[treasury].[BankAccounts]'))
    CREATE INDEX IX_BankAccounts_Company ON [treasury].[BankAccounts](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: CashBoxes per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.CashBoxes', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[CashBoxes] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CashBoxes_Company')
    ALTER TABLE [treasury].[CashBoxes] WITH CHECK ADD CONSTRAINT FK_CashBoxes_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[CashBoxes] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_CashBoxes INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_CashBoxes IS NOT NULL
        UPDATE [treasury].[CashBoxes] SET CompanyId = @DefaultCompanyId_CashBoxes WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CashBoxes_Company' AND object_id = OBJECT_ID(N'[treasury].[CashBoxes]'))
    CREATE INDEX IX_CashBoxes_Company ON [treasury].[CashBoxes](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: CurrencyRates per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.CurrencyRates', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[CurrencyRates] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CurrencyRates_Company')
    ALTER TABLE [treasury].[CurrencyRates] WITH CHECK ADD CONSTRAINT FK_CurrencyRates_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[CurrencyRates] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_CurrencyRates INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_CurrencyRates IS NOT NULL
        UPDATE [treasury].[CurrencyRates] SET CompanyId = @DefaultCompanyId_CurrencyRates WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CurrencyRates_Company' AND object_id = OBJECT_ID(N'[treasury].[CurrencyRates]'))
    CREATE INDEX IX_CurrencyRates_Company ON [treasury].[CurrencyRates](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: CashMovements per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.CashMovements', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[CashMovements] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CashMovements_Company')
    ALTER TABLE [treasury].[CashMovements] WITH CHECK ADD CONSTRAINT FK_CashMovements_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[CashMovements] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_CashMovements INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_CashMovements IS NOT NULL
        UPDATE [treasury].[CashMovements] SET CompanyId = @DefaultCompanyId_CashMovements WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CashMovements_Company' AND object_id = OBJECT_ID(N'[treasury].[CashMovements]'))
    CREATE INDEX IX_CashMovements_Company ON [treasury].[CashMovements](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Cheques per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.Cheques', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD CompanyId INT NULL;
GO
-- Cheque lifecycle timestamps + return reason (collected/returned management)
IF COL_LENGTH(N'treasury.Cheques', N'CollectedAt') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD CollectedAt DATETIME2 NULL;
GO
IF COL_LENGTH(N'treasury.Cheques', N'ReturnedAt') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD ReturnedAt DATETIME2 NULL;
GO
IF COL_LENGTH(N'treasury.Cheques', N'ReturnReason') IS NULL
    ALTER TABLE [treasury].[Cheques] ADD ReturnReason NVARCHAR(500) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Cheques_Company')
    ALTER TABLE [treasury].[Cheques] WITH CHECK ADD CONSTRAINT FK_Cheques_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[Cheques] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Cheques INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Cheques IS NOT NULL
        UPDATE [treasury].[Cheques] SET CompanyId = @DefaultCompanyId_Cheques WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Cheques_Company' AND object_id = OBJECT_ID(N'[treasury].[Cheques]'))
    CREATE INDEX IX_Cheques_Company ON [treasury].[Cheques](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: DayCloses per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'treasury.DayCloses', N'CompanyId') IS NULL
    ALTER TABLE [treasury].[DayCloses] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_DayCloses_Company')
    ALTER TABLE [treasury].[DayCloses] WITH CHECK ADD CONSTRAINT FK_DayCloses_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [treasury].[DayCloses] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_DayCloses INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_DayCloses IS NOT NULL
        UPDATE [treasury].[DayCloses] SET CompanyId = @DefaultCompanyId_DayCloses WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_DayCloses_Company' AND object_id = OBJECT_ID(N'[treasury].[DayCloses]'))
    CREATE INDEX IX_DayCloses_Company ON [treasury].[DayCloses](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- TreasurySettings — تنظیمات اتصال خزانه به حسابداری (مثل GoldShopSettings)
-- حساب‌های سند حسابداری دریافت/پرداخت + گروه تفصیلی مشتری/تأمین‌کننده
-- ─────────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'TreasurySettings')
BEGIN
    CREATE TABLE [treasury].[TreasurySettings] (
        CompanyId              INT NOT NULL PRIMARY KEY,
        CashAccountId          INT NULL,
        CashAccountCode        NVARCHAR(4000) NULL,
        CashAccountTitle       NVARCHAR(200) NULL,
        BankChartAccountId     INT NULL,
        BankChartAccountCode   NVARCHAR(4000) NULL,
        BankChartAccountTitle  NVARCHAR(200) NULL,
        ReceiveContraAccountId   INT NULL,
        ReceiveContraAccountCode NVARCHAR(4000) NULL,
        ReceiveContraAccountTitle NVARCHAR(200) NULL,
        PayContraAccountId       INT NULL,
        PayContraAccountCode     NVARCHAR(4000) NULL,
        PayContraAccountTitle    NVARCHAR(200) NULL,
        CustomerAccountGroupId INT NULL,
        SupplierAccountGroupId INT NULL,
        DefaultCashBoxId       INT NULL,
        DefaultBankAccountId   INT NULL,
        IsEnabled              BIT NOT NULL DEFAULT 1,
        UpdatedAt              DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedBy              NVARCHAR(100) NULL,
        CONSTRAINT FK_TreasurySettings_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END

-- ─────────────────────────────────────────────────────────────
-- PartyLinks — لینک حسابداری مشترک طرف حساب (مشتری/تأمین‌کننده)
-- صاحب واحد: خزانه‌داری؛ طلافروشی هم از همین جدول می‌خواند/می‌نویسد تا
-- تعریف مشتریان «یک‌پارچه» باشد (یک‌بار تعریف، همه‌جا استفاده).
-- ─────────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'treasury' AND t.name = N'PartyLinks')
BEGIN
    CREATE TABLE [treasury].[PartyLinks] (
        CompanyId         INT NOT NULL,
        PartyId           INT NOT NULL,
        PartyType         NVARCHAR(30) NOT NULL,      -- Customer | Vendor
        DetailLinkId      INT NULL,                   -- DetilId در حسابداری
        DetailAccountCode NVARCHAR(50) NULL,
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedAt         DATETIME2 NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        CONSTRAINT PK_TreasuryPartyLinks PRIMARY KEY (CompanyId, PartyId),
        CONSTRAINT FK_TreasuryPartyLinks_Party FOREIGN KEY (PartyId) REFERENCES [central].[Parties](PartyId)
    );
END

-- مهاجرت: کپی ردیف‌های لینک قدیمی طلافروشی به جدول یکپارچه (idempotent)
IF OBJECT_ID(N'goldshop.GoldPartyLinks', N'U') IS NOT NULL
BEGIN
    INSERT INTO [treasury].[PartyLinks]
        (CompanyId, PartyId, PartyType, DetailLinkId, DetailAccountCode, CreatedAt, CreatedBy)
    SELECT g.CompanyId, g.PartyId, g.PartyType, g.DetailLinkId, g.DetailAccountCode, g.CreatedAt, g.CreatedBy
    FROM [goldshop].[GoldPartyLinks] g
    WHERE NOT EXISTS (SELECT 1 FROM [treasury].[PartyLinks] t
                      WHERE t.CompanyId = g.CompanyId AND t.PartyId = g.PartyId);
END

-- ─────────────────────────────────────────────────────────────
-- مهاجرت یکتایی کدها از «سراسری» به «درون‌شرکتی» در خزانه‌داری
-- CREATE TABLE های قدیمی BankCode/CashBoxCode/CurrencyCode/DayDate را
-- UNIQUE سراسری می‌کردند که با قانون چندشرکتی ناسازگار بود. قید خودکار
-- قدیمی حذف و ایندکس یکتای فیلترشده (شرکت + کد) جایگزین می‌شود.
-- ─────────────────────────────────────────────────────────────
DECLARE @TrsUqTable NVARCHAR(128), @TrsUqName NVARCHAR(128), @TrsUqCol NVARCHAR(128), @TrsUqSql NVARCHAR(500);
DECLARE trs_uq CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.name AS Tbl, kc.name AS UqName, c.name AS ColName
    FROM sys.key_constraints kc
    JOIN sys.tables t ON t.object_id = kc.parent_object_id
    JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE t.schema_id = SCHEMA_ID(N'treasury') AND kc.type = N'UQ'
      AND t.name IN (N'Banks', N'CashBoxes', N'CurrencyRates', N'DayCloses')
      AND c.name IN (N'BankCode', N'CashBoxCode', N'CurrencyCode', N'DayDate');
OPEN trs_uq;
FETCH NEXT FROM trs_uq INTO @TrsUqTable, @TrsUqName, @TrsUqCol;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @TrsUqSql = N'ALTER TABLE [treasury].' + QUOTENAME(@TrsUqTable) + N' DROP CONSTRAINT ' + QUOTENAME(@TrsUqName) + N';';
    EXEC sp_executesql @TrsUqSql;
    FETCH NEXT FROM trs_uq INTO @TrsUqTable, @TrsUqName, @TrsUqCol;
END
CLOSE trs_uq;
DEALLOCATE trs_uq;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Banks_Company_Code' AND object_id = OBJECT_ID(N'[treasury].[Banks]'))
    CREATE UNIQUE INDEX UX_Banks_Company_Code ON [treasury].[Banks](CompanyId, BankCode) WHERE IsDeleted = 0 AND CompanyId IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_CashBoxes_Company_Code' AND object_id = OBJECT_ID(N'[treasury].[CashBoxes]'))
    CREATE UNIQUE INDEX UX_CashBoxes_Company_Code ON [treasury].[CashBoxes](CompanyId, CashBoxCode) WHERE IsDeleted = 0 AND CompanyId IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_CurrencyRates_Company_Code' AND object_id = OBJECT_ID(N'[treasury].[CurrencyRates]'))
    CREATE UNIQUE INDEX UX_CurrencyRates_Company_Code ON [treasury].[CurrencyRates](CompanyId, CurrencyCode) WHERE IsDeleted = 0 AND CompanyId IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_DayCloses_Company_Date' AND object_id = OBJECT_ID(N'[treasury].[DayCloses]'))
    CREATE UNIQUE INDEX UX_DayCloses_Company_Date ON [treasury].[DayCloses](CompanyId, DayDate) WHERE CompanyId IS NOT NULL;
GO
