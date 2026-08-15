-- =============================================
-- Tarazin.Data/Scripts/currency/_Ensure.sql
-- Schema: currency (ارز و معاملات ارزی — PRD §34–§63)
-- Endpoint: execute (startup)
--
-- این اسکیمه «مرکز نرخ‌ها و قیمت‌ها» و موتور معاملات ارز است:
--   Currencies          ← تعریف ارزها (ریال/تومان/…/ارز جدید)
--   PriceItems          ← کاتالوگ مرکز قیمت (ارز/طلا/سکه/فلز)
--   PriceRates          ← انواع نرخ هر آیتم (آنلاین/سیستم/خرید/فروش/…)
--   PriceSources        ← منابع دریافت آنلاین (TabloTala IR/FR/…)
--   PriceSourceValues   ← آخرین مقدار هر منبع (برای مقایسه §59)
--   RateHistory         ← تاریخچهٔ همهٔ تغییرات نرخ (§49)
--   Wallets             ← کیف پول هر ارز (§36)
--   CurrencyMovements   ← گردش ارز (§36/§37)
--   FxTransactions      ← سربرگ معاملات ارز/ترکیبی (§37/§38/§39)
--   FxTransactionLegs   ← پاهای معامله (ترکیبی §38)
--   AssetHoldings       ← دارایی فیزیکی (طلا/سکه/فلز) برای ارزش‌گذاری (§50/§51)
--   AssetValuationHistory← اسنپ‌شات روزانهٔ ارزش دارایی (§51)
--   Settings            ← تنظیمات (واحد پایه ریال، فاصلهٔ بروزرسانی، …)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'currency')
    EXEC(N'CREATE SCHEMA [currency]');

-- ── Currencies (تعریف ارز) — PRD §34/§35 ────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'Currencies')
BEGIN
    CREATE TABLE [currency].[Currencies] (
        CurrencyId   INT IDENTITY(1,1) PRIMARY KEY,
        CurrencyCode NVARCHAR(10) NOT NULL UNIQUE,   -- IRR | TOMAN | USD | EUR | …
        CurrencyName NVARCHAR(80) NOT NULL,
        Symbol       NVARCHAR(10) NULL,
        IsBase       BIT NOT NULL DEFAULT 0,         -- واحد پایهٔ سیستم = ریال
        UnitFactor   DECIMAL(18,4) NOT NULL DEFAULT 1, -- ضریب به ریال (TOMAN=10)
        IsActive     BIT NOT NULL DEFAULT 1,
        IsDeleted    BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL,
        CreatedBy    NVARCHAR(100) NULL,
        UpdatedBy    NVARCHAR(100) NULL
    );
END

-- ── PriceItems (کاتالوگ مرکز قیمت) — PRD §43 ────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'PriceItems')
BEGIN
    CREATE TABLE [currency].[PriceItems] (
        PriceItemId INT IDENTITY(1,1) PRIMARY KEY,
        ItemType    NVARCHAR(20) NOT NULL,           -- Currency | Gold | Coin | Metal | FxParity | Global
        ItemKey     NVARCHAR(50) NOT NULL UNIQUE,    -- USD | XAU-18 | SIKKEH-EMAMI | XAG
        Title       NVARCHAR(200) NOT NULL,
        Unit        NVARCHAR(30) NULL,               -- گرم | سکه | انس | واحد
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL,
        UpdatedBy   NVARCHAR(100) NULL
    );
    CREATE INDEX IX_PriceItems_Type ON [currency].[PriceItems](ItemType, IsDeleted);
END

-- ── PriceRates (انواع نرخ هر آیتم — مرکز قیمت واحد §60) ─────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'PriceRates')
BEGIN
    CREATE TABLE [currency].[PriceRates] (
        RateId          INT IDENTITY(1,1) PRIMARY KEY,
        PriceItemId     INT NOT NULL UNIQUE,
        OnlineRate      DECIMAL(24,6) NULL,          -- نرخ آنلاین (مرجع — وارد معامله نمی‌شود)
        ManualRate      DECIMAL(24,6) NULL,          -- نرخ دستی
        SystemRate      DECIMAL(24,6) NOT NULL DEFAULT 0, -- نرخ سیستم — تنها نرخ معاملات
        BuyRate         DECIMAL(24,6) NULL,          -- نرخ خرید
        SellRate        DECIMAL(24,6) NULL,          -- نرخ فروش
        AccountingRate  DECIMAL(24,6) NULL,          -- نرخ حسابداری
        MidRate         DECIMAL(24,6) NULL,          -- نرخ میانی
        Spread          DECIMAL(24,6) NULL,          -- Spread = Sell − Buy
        SourceKey       NVARCHAR(50) NULL,           -- منبع نرخ آنلاین فعال
        PrevValue       DECIMAL(24,6) NULL,          -- نرخ قبلی (§45)
        ChangePercent   DECIMAL(12,4) NULL,          -- درصد تغییر (§45)
        ChangeAmount    DECIMAL(24,6) NULL,          -- مبلغ تغییر (§45)
        IsOverride      BIT NOT NULL DEFAULT 0,      -- نرخ سیستم override شده (§46)
        IsValid         BIT NOT NULL DEFAULT 1,      -- معتبر بودن نرخ (§45/§57)
        Status          NVARCHAR(30) NOT NULL DEFAULT N'Active', -- Active | Stale | Offline
        LastFetchAt     DATETIME2 NULL,              -- آخرین دریافت آنلاین
        LastChangeAt    DATETIME2 NULL,              -- آخرین تغییر
        RateDate        DATE NULL,
        CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedBy       NVARCHAR(100) NULL,
        CONSTRAINT FK_PriceRates_Items FOREIGN KEY (PriceItemId) REFERENCES [currency].[PriceItems](PriceItemId)
    );
END

-- ── PriceSources (منابع قیمت) — PRD §44/§45/§57/§58/§61 ────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'PriceSources')
BEGIN
    CREATE TABLE [currency].[PriceSources] (
        SourceId             INT IDENTITY(1,1) PRIMARY KEY,
        SourceKey            NVARCHAR(50) NOT NULL UNIQUE, -- TABLOTALA | TABLOTALA_FR | MANUAL
        Title                NVARCHAR(120) NOT NULL,
        BaseUrl              NVARCHAR(300) NULL,
        Endpoint             NVARCHAR(500) NULL,      -- آدرس API/Feed رسمی
        MappingsJson         NVARCHAR(MAX) NULL,      -- نگاشت آیتم‌ها ← مسیر پاسخ (JSON)
        IsActive             BIT NOT NULL DEFAULT 1,
        Priority             INT NOT NULL DEFAULT 100, -- ترتیب بررسی منابع (§58)
        FetchIntervalSeconds INT NOT NULL DEFAULT 300, -- فاصلهٔ بروزرسانی (§56)
        Status               NVARCHAR(30) NOT NULL DEFAULT N'Unknown', -- Online | Offline | Disabled
        LastFetchAt          DATETIME2 NULL,
        LastSuccessAt        DATETIME2 NULL,
        LastValidAt          DATETIME2 NULL,
        LastError            NVARCHAR(500) NULL,
        ErrorCount           INT NOT NULL DEFAULT 0,
        CreatedAt            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt            DATETIME2 NULL,
        CreatedBy            NVARCHAR(100) NULL,
        UpdatedBy            NVARCHAR(100) NULL
    );
END

-- ── PriceSourceValues (آخرین مقدار هر منبع — مقایسه §59) ────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'PriceSourceValues')
BEGIN
    CREATE TABLE [currency].[PriceSourceValues] (
        SourceValueId BIGINT IDENTITY(1,1) PRIMARY KEY,
        SourceKey     NVARCHAR(50) NOT NULL,
        PriceItemId   INT NOT NULL,
        Value         DECIMAL(24,6) NOT NULL,
        FetchedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_PSV_Item FOREIGN KEY (PriceItemId) REFERENCES [currency].[PriceItems](PriceItemId),
        CONSTRAINT UX_PSV UNIQUE (SourceKey, PriceItemId)
    );
END

-- ── RateHistory (تاریخچهٔ نرخ‌ها) — PRD §49 ─────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'RateHistory')
BEGIN
    CREATE TABLE [currency].[RateHistory] (
        HistoryId   BIGINT IDENTITY(1,1) PRIMARY KEY,
        ItemType    NVARCHAR(20) NOT NULL,            -- Currency | Gold | Coin | Metal | FxParity | Global
        ItemKey     NVARCHAR(50) NOT NULL,
        RateKind    NVARCHAR(30) NOT NULL,            -- Online | System | Manual | Buy | Sell | Accounting | Transaction
        PrevValue   DECIMAL(24,6) NULL,
        NewValue    DECIMAL(24,6) NOT NULL,
        SourceKey   NVARCHAR(50) NULL,
        ChangeType  NVARCHAR(20) NOT NULL DEFAULT N'Manual', -- AutoFetch | Manual | Override | Transaction
        Reason      NVARCHAR(300) NULL,
        ChangedBy   NVARCHAR(100) NULL,
        ChangedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        IsOnline    BIT NOT NULL DEFAULT 0
    );
    CREATE INDEX IX_RateHistory_Item ON [currency].[RateHistory](ItemType, ItemKey, ChangedAt DESC);
END

-- ── Wallets (کیف پول ارز) — PRD §36 ─────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'Wallets')
BEGIN
    CREATE TABLE [currency].[Wallets] (
        WalletId       INT IDENTITY(1,1) PRIMARY KEY,
        CurrencyCode   NVARCHAR(10) NOT NULL UNIQUE,
        Quantity       DECIMAL(18,4) NOT NULL DEFAULT 0,
        AvgBuyRate     DECIMAL(18,2) NULL,            -- نرخ متوسط خرید
        OpeningQty     DECIMAL(18,4) NOT NULL DEFAULT 0,   -- موجودی اول دوره
        OpeningAvgRate DECIMAL(18,2) NULL,
        InQty          DECIMAL(18,4) NOT NULL DEFAULT 0,   -- ورود دوره
        OutQty         DECIMAL(18,4) NOT NULL DEFAULT 0,   -- خروج دوره
        LastMovementAt DATETIME2 NULL,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedBy      NVARCHAR(100) NULL
    );
END

-- ── CurrencyMovements (گردش ارز) — PRD §36/§37 ──────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'CurrencyMovements')
BEGIN
    CREATE TABLE [currency].[CurrencyMovements] (
        MovementId       BIGINT IDENTITY(1,1) PRIMARY KEY,
        MovementNumber   NVARCHAR(50) NOT NULL,
        MovementDate     DATE NOT NULL,
        MovementTime     TIME(0) NULL,
        MovementType     NVARCHAR(30) NOT NULL,       -- Buy | Sell | In | Out | Transfer | Conversion | Adjustment
        Direction        NVARCHAR(10) NOT NULL,       -- In | Out
        CurrencyCode     NVARCHAR(10) NOT NULL,
        Quantity         DECIMAL(18,4) NOT NULL,
        Rate             DECIMAL(18,2) NOT NULL,      -- نرخ معامله (قفل‌شده §48)
        AmountRial       DECIMAL(18,2) NOT NULL,
        CounterPartyName NVARCHAR(200) NULL,
        FundType         NVARCHAR(20) NULL,           -- Cash | Bank
        FundId           INT NULL,
        FxTransactionId  INT NULL,
        DocumentId       INT NULL,
        SourceReference  NVARCHAR(100) NULL,
        Description      NVARCHAR(300) NULL,
        CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(100) NULL
    );
    CREATE INDEX IX_CurrencyMovements_Date ON [currency].[CurrencyMovements](MovementDate);
    CREATE INDEX IX_CurrencyMovements_Currency ON [currency].[CurrencyMovements](CurrencyCode, MovementDate);
    CREATE UNIQUE INDEX UX_CurrencyMovements_Source
        ON [currency].[CurrencyMovements](SourceReference)
        WHERE SourceReference IS NOT NULL AND SourceReference <> N'';
END

-- ── FxTransactions (سربرگ معاملات ارز) — PRD §37/§38/§39 ────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'FxTransactions')
BEGIN
    CREATE TABLE [currency].[FxTransactions] (
        FxTransactionId   INT IDENTITY(1,1) PRIMARY KEY,
        TransactionNumber NVARCHAR(50) NOT NULL,
        TransactionDate   DATE NOT NULL,
        TransactionTime   TIME(0) NULL,
        TransactionType   NVARCHAR(30) NOT NULL,      -- Buy | Sell | Conversion | Combined | Transfer
        PartyName         NVARCHAR(200) NULL,
        Status            NVARCHAR(30) NOT NULL DEFAULT N'Posted',
        TotalRial         DECIMAL(18,2) NOT NULL DEFAULT 0,
        DocumentId        INT NULL,                   -- سند حسابداری
        Description       NVARCHAR(500) NULL,
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL
    );
    CREATE INDEX IX_FxTransactions_Date ON [currency].[FxTransactions](TransactionDate);
END

-- ── FxTransactionLegs (پاهای معامله — ترکیبی §38) ───────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'FxTransactionLegs')
BEGIN
    CREATE TABLE [currency].[FxTransactionLegs] (
        LegId           BIGINT IDENTITY(1,1) PRIMARY KEY,
        FxTransactionId INT NOT NULL,
        LegType         NVARCHAR(20) NOT NULL,        -- Currency | Gold | Coin | Metal | Rial
        ItemKey         NVARCHAR(50) NOT NULL,
        Title           NVARCHAR(200) NULL,
        Direction       NVARCHAR(10) NOT NULL,        -- In | Out
        Quantity        DECIMAL(18,4) NULL,
        Rate            DECIMAL(18,2) NULL,           -- نرخ قفل‌شدهٔ معامله (§48)
        AmountRial      DECIMAL(18,2) NOT NULL,
        RealizedPnl     DECIMAL(18,2) NULL,           -- سود/زیان محقق‌شده (§52)
        FundType        NVARCHAR(20) NULL,
        FundId          INT NULL,
        Description     NVARCHAR(300) NULL,
        CONSTRAINT FK_FxLegs_Transaction FOREIGN KEY (FxTransactionId) REFERENCES [currency].[FxTransactions](FxTransactionId)
    );
    CREATE INDEX IX_FxLegs_Transaction ON [currency].[FxTransactionLegs](FxTransactionId);
END

-- ── AssetHoldings (دارایی فیزیکی: طلا/سکه/فلز) — PRD §50/§51 ────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'AssetHoldings')
BEGIN
    CREATE TABLE [currency].[AssetHoldings] (
        HoldingId    INT IDENTITY(1,1) PRIMARY KEY,
        ItemKey      NVARCHAR(50) NOT NULL UNIQUE,   -- XAU-18 | SIKKEH-EMAMI | XAG
        Title        NVARCHAR(200) NOT NULL,
        Quantity     DECIMAL(18,4) NOT NULL DEFAULT 0,
        CostRate     DECIMAL(18,2) NULL,             -- نرخ خرید ثبت‌شده (برای سود/زیان ارزش)
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedBy    NVARCHAR(100) NULL
    );
END

-- ── AssetValuationHistory (اسنپ‌شات ارزش دارایی) — PRD §51 ───────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'AssetValuationHistory')
BEGIN
    CREATE TABLE [currency].[AssetValuationHistory] (
        SnapshotId   INT IDENTITY(1,1) PRIMARY KEY,
        SnapshotDate DATE NOT NULL,
        TotalRial    DECIMAL(18,2) NOT NULL DEFAULT 0,
        CashPart     DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyPart DECIMAL(18,2) NOT NULL DEFAULT 0,
        GoldPart     DECIMAL(18,2) NOT NULL DEFAULT 0,
        CoinPart     DECIMAL(18,2) NOT NULL DEFAULT 0,
        MetalPart    DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(100) NULL
    );
    CREATE INDEX IX_AssetValuation_Date ON [currency].[AssetValuationHistory](SnapshotDate);
END

-- ── Settings (تنظیمات ارز) — PRD §35/§56 ────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'currency' AND t.name = N'Settings')
BEGIN
    CREATE TABLE [currency].[Settings] (
        SettingKey   NVARCHAR(50) NOT NULL PRIMARY KEY,
        SettingValue NVARCHAR(300) NOT NULL,
        Description  NVARCHAR(300) NULL
    );
END
GO

-- ── Migration: حفظ اعشار API رسمی (FR تا ۴ رقم اعشار دارد) ──────────────
-- نسخهٔ قدیمی DECIMAL(18,2) بود و مثلاً EUR/USD=1.1567 را به 1.16 تبدیل
-- می‌کرد. فقط در دیتابیس‌های قدیمی اجرا می‌شود و دادهٔ موجود را حفظ می‌کند.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'OnlineRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN OnlineRate DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'ManualRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN ManualRate DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'SystemRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN SystemRate DECIMAL(24,6) NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'BuyRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN BuyRate DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'SellRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN SellRate DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'AccountingRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN AccountingRate DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'MidRate' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN MidRate DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'Spread' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN Spread DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'PrevValue' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN PrevValue DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceRates') AND name = N'ChangeAmount' AND scale < 6)
    ALTER TABLE [currency].[PriceRates] ALTER COLUMN ChangeAmount DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.PriceSourceValues') AND name = N'Value' AND scale < 6)
    ALTER TABLE [currency].[PriceSourceValues] ALTER COLUMN Value DECIMAL(24,6) NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.RateHistory') AND name = N'PrevValue' AND scale < 6)
    ALTER TABLE [currency].[RateHistory] ALTER COLUMN PrevValue DECIMAL(24,6) NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'currency.RateHistory') AND name = N'NewValue' AND scale < 6)
    ALTER TABLE [currency].[RateHistory] ALTER COLUMN NewValue DECIMAL(24,6) NOT NULL;
