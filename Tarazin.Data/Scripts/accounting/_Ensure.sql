-- =============================================
-- Tarazin.Data/Scripts/accounting/_Ensure.sql
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

-- Journal lines (double-entry): the debit/credit detail behind each document.
-- Reports (دفتر روزنامه / دفتر کل / تراز آزمایشی) are computed from these.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'DocumentLines')
BEGIN
    CREATE TABLE [accounting].[DocumentLines] (
        DocumentLineId  INT IDENTITY(1,1) PRIMARY KEY,
        DocumentId      INT NOT NULL,
        AccountId       INT NOT NULL,
        AccountCode     NVARCHAR(30) NOT NULL,
        Title           NVARCHAR(200) NOT NULL,
        Description     NVARCHAR(500) NULL,
        Debit           DECIMAL(18,2) NOT NULL DEFAULT 0,
        Credit          DECIMAL(18,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_DocumentLines_Document FOREIGN KEY (DocumentId) REFERENCES [accounting].[Documents](DocumentId)
    );
    CREATE INDEX IX_DocumentLines_Document ON [accounting].[DocumentLines](DocumentId);
    -- ایندکس برای جستجوی HasUsage روی AccountCode (LIKE prefix)
    CREATE INDEX IX_DocumentLines_AccountCode ON [accounting].[DocumentLines](AccountCode) INCLUDE (AccountId, Title);
END

-- Contract: ChartOfAccount (owner: accounting).
-- (نگه‌داشته شده برای سازگاری با گزارش‌های قدیمی؛ جداول پایهٔ جدید جایگزین شدند)
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

-- =============================================
-- جداول پایهٔ چندسطحی: BaseCol (کل) / BaseMoein (معین) / BaseDetil (تفصیلی سطح ۳+)
-- طراحی مطابق PRD §جداول پایه:
--   - BaseCol.Code: 2 رقم
--   - BaseMoein.Code: 3 رقم
--   - BaseDetil.Code: 7 رقم
--   - AccountCode = ترکیب مسیر BaseCol + BaseMoein + BaseDetil[...]
--   - تفصیلی یکپارچه: BaseDetil یک‌بار ایجاد می‌شود و در چند مسیر قرار می‌گیرد.
--   - سطح ۴+ با ParentLinkId خودارجاع در BaseDetilLink ساخته می‌شود.
-- =============================================

-- BaseCol — حساب کل
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'BaseCol')
BEGIN
    CREATE TABLE [accounting].[BaseCol] (
        ColId          INT IDENTITY(1,1) PRIMARY KEY,
        ColCode        NVARCHAR(2) NOT NULL UNIQUE,    -- دقیقاً 2 رقم، صفرهای ابتدایی حفظ می‌شود
        Title          NVARCHAR(200) NOT NULL,
        [Description]  NVARCHAR(500) NULL,
        IsActive       BIT NOT NULL DEFAULT 1,
        IsDeleted      BIT NOT NULL DEFAULT 0,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CreatedBy      NVARCHAR(100) NULL,
        UpdatedBy      NVARCHAR(100) NULL
    );
    CREATE INDEX IX_BaseCol_Code ON [accounting].[BaseCol](ColCode);
END

-- ایندکس‌های اضافی برای بهینه‌سازی Tree
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseCol_Deleted_Active' AND object_id = OBJECT_ID(N'[accounting].[BaseCol]'))
    CREATE INDEX IX_BaseCol_Deleted_Active ON [accounting].[BaseCol](IsDeleted, IsActive) INCLUDE (ColCode, Title);
GO

-- BaseMoein — حساب معین (زیرمجموعهٔ BaseCol)
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'BaseMoein')
BEGIN
    CREATE TABLE [accounting].[BaseMoein] (
        MoeinId        INT IDENTITY(1,1) PRIMARY KEY,
        ColId          INT NOT NULL,                  -- FK → BaseCol
        MoeinCode      NVARCHAR(3) NOT NULL,           -- دقیقاً 3 رقم
        Title          NVARCHAR(200) NOT NULL,
        [Description]  NVARCHAR(500) NULL,
        IsActive       BIT NOT NULL DEFAULT 1,
        IsDeleted      BIT NOT NULL DEFAULT 0,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CreatedBy      NVARCHAR(100) NULL,
        UpdatedBy      NVARCHAR(100) NULL,
        CONSTRAINT FK_BaseMoein_BaseCol FOREIGN KEY (ColId) REFERENCES [accounting].[BaseCol](ColId)
    );
    CREATE UNIQUE INDEX UX_BaseMoein_Col_Code ON [accounting].[BaseMoein](ColId, MoeinCode);
    CREATE INDEX IX_BaseMoein_Col ON [accounting].[BaseMoein](ColId);
END

-- ایندکس‌های اضافی برای بهینه‌سازی درخت + جستجو (با درنظر گرفتن هزاران رکورد)
-- ترکیب (IsDeleted, IsActive) بهینه‌سازی فیلترهای پرتکرار Tree است.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseMoein_Deleted_Active' AND object_id = OBJECT_ID(N'[accounting].[BaseMoein]'))
    CREATE INDEX IX_BaseMoein_Deleted_Active ON [accounting].[BaseMoein](IsDeleted, IsActive) INCLUDE (MoeinCode, Title, ColId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseMoein_Title' AND object_id = OBJECT_ID(N'[accounting].[BaseMoein]'))
    CREATE INDEX IX_BaseMoein_Title ON [accounting].[BaseMoein](Title) INCLUDE (MoeinCode, ColId, IsDeleted);
GO

-- BaseDetil — حساب تفصیلی (یکپارچه/Shared)
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'BaseDetil')
BEGIN
    CREATE TABLE [accounting].[BaseDetil] (
        DetilId        INT IDENTITY(1,1) PRIMARY KEY,
        DetilCode      NVARCHAR(7) NOT NULL UNIQUE,    -- دقیقاً 7 رقم، یکتا در کل سیستم
        Title          NVARCHAR(200) NOT NULL,
        [Description]  NVARCHAR(500) NULL,
        IsActive       BIT NOT NULL DEFAULT 1,
        IsDeleted      BIT NOT NULL DEFAULT 0,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CreatedBy      NVARCHAR(100) NULL,
        UpdatedBy      NVARCHAR(100) NULL
    );
    CREATE INDEX IX_BaseDetil_Code ON [accounting].[BaseDetil](DetilCode);
END

-- ایندکس‌های بهینه برای جستجوی BaseDetil در Picker/Tree
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseDetil_Deleted_Active' AND object_id = OBJECT_ID(N'[accounting].[BaseDetil]'))
    CREATE INDEX IX_BaseDetil_Deleted_Active ON [accounting].[BaseDetil](IsDeleted, IsActive) INCLUDE (DetilCode, Title);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseDetil_Title' AND object_id = OBJECT_ID(N'[accounting].[BaseDetil]'))
    CREATE INDEX IX_BaseDetil_Title ON [accounting].[BaseDetil](Title) INCLUDE (DetilCode, IsDeleted);
GO

-- BaseDetilLink — «محل قرارگیری» یک تفصیلی در درخت.
-- ParentLinkId=NULL یعنی سطح ۳ و فرزند مستقیم Moein؛ مقدار غیر NULL یعنی
-- فرزند یک محل قرارگیری تفصیلی دیگر (سطح ۴ به بعد). MoeinId روی همهٔ نسل‌ها
-- نگه داشته می‌شود تا مالک مسیر و کنترل یکپارچگی سریع و صریح باشد.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'BaseDetilLink')
BEGIN
    CREATE TABLE [accounting].[BaseDetilLink] (
        LinkId         INT IDENTITY(1,1) PRIMARY KEY,
        DetilId        INT NOT NULL,                  -- FK → BaseDetil (موجودیت مشترک)
        MoeinId        INT NOT NULL,                  -- FK → BaseMoein (ریشهٔ مسیر)
        ParentLinkId   INT NULL,                      -- NULL=سطح۳؛ FK خودارجاع=سطح۴+
        [Description]  NVARCHAR(500) NULL,
        IsActive       BIT NOT NULL DEFAULT 1,
        IsDeleted      BIT NOT NULL DEFAULT 0,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CreatedBy      NVARCHAR(100) NULL,
        UpdatedBy      NVARCHAR(100) NULL,
        CONSTRAINT FK_BaseDetilLink_Detil FOREIGN KEY (DetilId) REFERENCES [accounting].[BaseDetil](DetilId),
        CONSTRAINT FK_BaseDetilLink_Moein FOREIGN KEY (MoeinId) REFERENCES [accounting].[BaseMoein](MoeinId),
        CONSTRAINT FK_BaseDetilLink_Parent FOREIGN KEY (ParentLinkId) REFERENCES [accounting].[BaseDetilLink](LinkId)
    );
    CREATE INDEX IX_BaseDetilLink_Detil ON [accounting].[BaseDetilLink](DetilId);
    CREATE INDEX IX_BaseDetilLink_Moein ON [accounting].[BaseDetilLink](MoeinId);
    CREATE INDEX IX_BaseDetilLink_Parent ON [accounting].[BaseDetilLink](ParentLinkId);
END
GO

-- Migration برای دیتابیس‌های موجود: رکوردهای قدیمی با ParentLinkId=NULL همان
-- سطح ۳ باقی می‌مانند و هیچ داده‌ای جابه‌جا یا حذف نمی‌شود.
IF OBJECT_ID(N'accounting.BaseDetilLink', N'U') IS NOT NULL
   AND COL_LENGTH(N'accounting.BaseDetilLink', N'ParentLinkId') IS NULL
    ALTER TABLE [accounting].[BaseDetilLink] ADD ParentLinkId INT NULL;
GO

IF OBJECT_ID(N'accounting.BaseDetilLink', N'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.foreign_keys
       WHERE name = N'FK_BaseDetilLink_Parent'
         AND parent_object_id = OBJECT_ID(N'accounting.BaseDetilLink'))
    ALTER TABLE [accounting].[BaseDetilLink] WITH CHECK
        ADD CONSTRAINT FK_BaseDetilLink_Parent
        FOREIGN KEY (ParentLinkId) REFERENCES [accounting].[BaseDetilLink](LinkId);
GO

-- ایندکس‌های بهینه برای Link (حیاتی‌ترین جدول — بیشترین ردیف را دارد)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseDetilLink_Moein_Active' AND object_id = OBJECT_ID(N'[accounting].[BaseDetilLink]'))
    CREATE INDEX IX_BaseDetilLink_Moein_Active ON [accounting].[BaseDetilLink](MoeinId, IsDeleted, IsActive) INCLUDE (DetilId, ParentLinkId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseDetilLink_Detil_Active' AND object_id = OBJECT_ID(N'[accounting].[BaseDetilLink]'))
    CREATE INDEX IX_BaseDetilLink_Detil_Active ON [accounting].[BaseDetilLink](DetilId, IsDeleted, IsActive) INCLUDE (MoeinId, ParentLinkId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_BaseDetilLink_Parent_Active' AND object_id = OBJECT_ID(N'[accounting].[BaseDetilLink]'))
    CREATE INDEX IX_BaseDetilLink_Parent_Active ON [accounting].[BaseDetilLink](ParentLinkId, IsDeleted, IsActive) INCLUDE (DetilId, MoeinId);
GO

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

-- =============================================
-- Migrations: ایندکس‌هایی که فقط داخل CREATE TABLE ساخته می‌شدند.
-- روی دیتابیس‌هایی که جدول از قبل وجود داشت این ایندکس‌ها هرگز ساخته
-- نمی‌شدند؛ چون چند اسکریپت با WITH (INDEX(...)) به آن‌ها hint می‌دهند،
-- نبودشان خطای «Msg 308: index does not exist» می‌دهد و حذف/انتقال/جستجو
-- را می‌شکند. این بلوک idempotent آن‌ها را تضمین می‌کند.
-- =============================================
IF OBJECT_ID(N'accounting.DocumentLines', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_DocumentLines_AccountCode'
                     AND object_id = OBJECT_ID(N'accounting.DocumentLines'))
    CREATE INDEX IX_DocumentLines_AccountCode
        ON [accounting].[DocumentLines](AccountCode) INCLUDE (AccountId, Title);
GO

IF OBJECT_ID(N'accounting.DocumentLines', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_DocumentLines_Document'
                     AND object_id = OBJECT_ID(N'accounting.DocumentLines'))
    CREATE INDEX IX_DocumentLines_Document ON [accounting].[DocumentLines](DocumentId);
GO

IF OBJECT_ID(N'accounting.BaseMoein', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'UX_BaseMoein_Col_Code'
                     AND object_id = OBJECT_ID(N'accounting.BaseMoein'))
    CREATE UNIQUE INDEX UX_BaseMoein_Col_Code ON [accounting].[BaseMoein](ColId, MoeinCode);
GO

IF OBJECT_ID(N'accounting.BaseMoein', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_BaseMoein_Col'
                     AND object_id = OBJECT_ID(N'accounting.BaseMoein'))
    CREATE INDEX IX_BaseMoein_Col ON [accounting].[BaseMoein](ColId);
GO

IF OBJECT_ID(N'accounting.BaseCol', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_BaseCol_Code'
                     AND object_id = OBJECT_ID(N'accounting.BaseCol'))
    CREATE INDEX IX_BaseCol_Code ON [accounting].[BaseCol](ColCode);
GO

IF OBJECT_ID(N'accounting.BaseDetil', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_BaseDetil_Code'
                     AND object_id = OBJECT_ID(N'accounting.BaseDetil'))
    CREATE INDEX IX_BaseDetil_Code ON [accounting].[BaseDetil](DetilCode);
GO

IF OBJECT_ID(N'accounting.BaseDetilLink', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_BaseDetilLink_Detil'
                     AND object_id = OBJECT_ID(N'accounting.BaseDetilLink'))
    CREATE INDEX IX_BaseDetilLink_Detil ON [accounting].[BaseDetilLink](DetilId);
GO

IF OBJECT_ID(N'accounting.BaseDetilLink', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'IX_BaseDetilLink_Moein'
                     AND object_id = OBJECT_ID(N'accounting.BaseDetilLink'))
    CREATE INDEX IX_BaseDetilLink_Moein ON [accounting].[BaseDetilLink](MoeinId);
GO

-- =============================================
-- Migrations: تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy
-- =============================================
IF COL_LENGTH(N'accounting.DocumentLines', N'CreatedAt') IS NULL
    ALTER TABLE [accounting].[DocumentLines] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_DocumentLines_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'accounting.DocumentLines', N'UpdatedAt') IS NULL
    ALTER TABLE [accounting].[DocumentLines] ADD UpdatedAt DATETIME2 NULL;

IF COL_LENGTH(N'accounting.ChartOfAccounts', N'CreatedBy') IS NULL
    ALTER TABLE [accounting].[ChartOfAccounts] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'accounting.ChartOfAccounts', N'UpdatedBy') IS NULL
    ALTER TABLE [accounting].[ChartOfAccounts] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'accounting.TaxRules', N'CreatedBy') IS NULL
    ALTER TABLE [accounting].[TaxRules] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'accounting.TaxRules', N'UpdatedBy') IS NULL
    ALTER TABLE [accounting].[TaxRules] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'accounting.SalesInvoices', N'UpdatedAt') IS NULL
    ALTER TABLE [accounting].[SalesInvoices] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'accounting.SalesInvoices', N'CreatedBy') IS NULL
    ALTER TABLE [accounting].[SalesInvoices] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'accounting.SalesInvoices', N'UpdatedBy') IS NULL
    ALTER TABLE [accounting].[SalesInvoices] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'accounting.PayrollPostings', N'UpdatedAt') IS NULL
    ALTER TABLE [accounting].[PayrollPostings] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'accounting.InventoryLedger', N'UpdatedAt') IS NULL
    ALTER TABLE [accounting].[InventoryLedger] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'accounting.GoldPriceSnapshot', N'CreatedAt') IS NULL
    ALTER TABLE [accounting].[GoldPriceSnapshot] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_GoldPriceSnapshot_CreatedAt DEFAULT SYSUTCDATETIME();
