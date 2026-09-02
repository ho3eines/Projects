-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/store/_Ensure.sql
-- Schema: store (فروشگاه اینترنتی)
-- Endpoint: execute (startup)
-- =============================================
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'store')
    EXEC(N'CREATE SCHEMA [store]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Customers')
BEGIN
    CREATE TABLE [store].[Customers] (
        CustomerId   INT IDENTITY(1,1) PRIMARY KEY,
        CustomerCode NVARCHAR(30) NOT NULL UNIQUE,
        FullName     NVARCHAR(200) NOT NULL,
        Phone        NVARCHAR(30) NULL,
        Email        NVARCHAR(120) NULL,
        IsActive     BIT NOT NULL DEFAULT 1,
        IsDeleted    BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Products')
BEGIN
    CREATE TABLE [store].[Products] (
        ProductId    INT IDENTITY(1,1) PRIMARY KEY,
        ProductCode  NVARCHAR(50) NOT NULL UNIQUE,
        Title        NVARCHAR(200) NOT NULL,
        ItemCode     NVARCHAR(50) NULL,                -- link to inventory.Items.ItemCode
        Price        DECIMAL(18,2) NOT NULL DEFAULT 0,
        IsActive     BIT NOT NULL DEFAULT 1,
        IsDeleted    BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'CartItems')
BEGIN
    CREATE TABLE [store].[CartItems] (
        CartItemId  INT IDENTITY(1,1) PRIMARY KEY,
        CustomerId  INT NOT NULL,
        ProductId   INT NOT NULL,
        Qty         DECIMAL(18,3) NOT NULL DEFAULT 1,
        AddedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Cart_Products FOREIGN KEY (ProductId) REFERENCES [store].[Products](ProductId)
    );
    CREATE INDEX IX_Cart_Customer ON [store].[CartItems](CustomerId);
END

-- Contract: Order / Cart (owner: store).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Orders')
BEGIN
    CREATE TABLE [store].[Orders] (
        OrderId       INT IDENTITY(1,1) PRIMARY KEY,
        OrderNumber   NVARCHAR(50) NOT NULL,
        CustomerId    INT NOT NULL,
        CustomerName  NVARCHAR(200) NOT NULL,
        OrderDate     DATE NOT NULL,
        ItemCount     INT NOT NULL DEFAULT 0,
        TotalAmount   DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyCode  NVARCHAR(10) NOT NULL DEFAULT N'IRR',
        Status        NVARCHAR(30) NOT NULL DEFAULT N'Placed',  -- Placed | Reserved | Invoiced | Rejected | Cancelled
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_Orders_Date ON [store].[Orders](OrderDate, Status);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'OrderItems')
BEGIN
    CREATE TABLE [store].[OrderItems] (
        OrderItemId  INT IDENTITY(1,1) PRIMARY KEY,
        OrderId      INT NOT NULL,
        ProductId    INT NOT NULL,
        ProductTitle NVARCHAR(200) NOT NULL,
        Qty          DECIMAL(18,3) NOT NULL DEFAULT 1,
        UnitPrice    DECIMAL(18,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES [store].[Orders](OrderId)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'OrderReservations')
BEGIN
    CREATE TABLE [store].[OrderReservations] (
        ReservationId INT IDENTITY(1,1) PRIMARY KEY,
        OrderId       INT NOT NULL UNIQUE,             -- idempotency key
        ReservedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Consumer read-model: inventory snapshot.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'InventorySnapshot')
BEGIN
    CREATE TABLE [store].[InventorySnapshot] (
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

-- Consumer read-model: gold price snapshot.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'GoldPriceSnapshot')
BEGIN
    CREATE TABLE [store].[GoldPriceSnapshot] (
        SnapshotId    INT IDENTITY(1,1) PRIMARY KEY,
        ItemCode      NVARCHAR(50) NOT NULL UNIQUE,
        PricePerGram  DECIMAL(18,0) NOT NULL DEFAULT 0,
        UpdatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- Product categories (دسته‌بندی کالا) — نمونهٔ الگوی CRUD اسکیل.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'ProductCategories')
BEGIN
    CREATE TABLE [store].[ProductCategories] (
        CategoryId   INT IDENTITY(1,1) PRIMARY KEY,
        CategoryCode NVARCHAR(50) NOT NULL UNIQUE,
        Title        NVARCHAR(200) NOT NULL,
        SortOrder    INT NOT NULL DEFAULT 0,
        IsActive     BIT NOT NULL DEFAULT 1,
        IsDeleted    BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL,
        CreatedBy    NVARCHAR(100) NULL,
        UpdatedBy    NVARCHAR(100) NULL
    );
END

-- Multi-Company: ProductCategories per-company scoping
IF COL_LENGTH(N'store.ProductCategories', N'CompanyId') IS NULL
    ALTER TABLE [store].[ProductCategories] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ProductCategories_Company')
    ALTER TABLE [store].[ProductCategories] WITH CHECK ADD CONSTRAINT FK_ProductCategories_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
IF EXISTS (SELECT 1 FROM [store].[ProductCategories] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_ProductCategories INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_ProductCategories IS NOT NULL
        UPDATE [store].[ProductCategories] SET CompanyId = @DefaultCompanyId_ProductCategories WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ProductCategories_Company' AND object_id = OBJECT_ID(N'[store].[ProductCategories]'))
    CREATE INDEX IX_ProductCategories_Company ON [store].[ProductCategories](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- Event backbone (ADR-002).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Outbox')
BEGIN
    CREATE TABLE [store].[Outbox] (
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
    CREATE INDEX IX_Outbox_Ready ON [store].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
END

-- =============================================
-- Migrations: تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy
-- =============================================
IF COL_LENGTH(N'store.Customers', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[Customers] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'store.Customers', N'CreatedBy') IS NULL
    ALTER TABLE [store].[Customers] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'store.Customers', N'UpdatedBy') IS NULL
    ALTER TABLE [store].[Customers] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'store.Products', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[Products] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'store.Products', N'CreatedBy') IS NULL
    ALTER TABLE [store].[Products] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'store.Products', N'UpdatedBy') IS NULL
    ALTER TABLE [store].[Products] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'store.Orders', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[Orders] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'store.Orders', N'CreatedBy') IS NULL
    ALTER TABLE [store].[Orders] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'store.Orders', N'UpdatedBy') IS NULL
    ALTER TABLE [store].[Orders] ADD UpdatedBy NVARCHAR(100) NULL;

-- Migration: اتصال سفارش به شعبه (ماژول branch — BI §86).
IF COL_LENGTH(N'store.Orders', N'BranchId') IS NULL
    ALTER TABLE [store].[Orders] ADD BranchId INT NULL;

IF COL_LENGTH(N'store.GoldPriceSnapshot', N'CreatedAt') IS NULL
    ALTER TABLE [store].[GoldPriceSnapshot] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_store_GoldPriceSnapshot_CreatedAt DEFAULT SYSUTCDATETIME();

IF COL_LENGTH(N'store.OrderItems', N'CreatedAt') IS NULL
    ALTER TABLE [store].[OrderItems] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_OrderItems_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'store.OrderItems', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[OrderItems] ADD UpdatedAt DATETIME2 NULL;

IF COL_LENGTH(N'store.CartItems', N'CreatedAt') IS NULL
    ALTER TABLE [store].[CartItems] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_CartItems_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'store.CartItems', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[CartItems] ADD UpdatedAt DATETIME2 NULL;

IF COL_LENGTH(N'store.OrderReservations', N'CreatedAt') IS NULL
    ALTER TABLE [store].[OrderReservations] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_OrderReservations_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'store.OrderReservations', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[OrderReservations] ADD UpdatedAt DATETIME2 NULL;

IF COL_LENGTH(N'store.InventorySnapshot', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[InventorySnapshot] ADD UpdatedAt DATETIME2 NULL;

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Customers per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'store.Customers', N'CompanyId') IS NULL
    ALTER TABLE [store].[Customers] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Customers_Company')
    ALTER TABLE [store].[Customers] WITH CHECK ADD CONSTRAINT FK_Customers_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [store].[Customers] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Customers INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Customers IS NOT NULL
        UPDATE [store].[Customers] SET CompanyId = @DefaultCompanyId_Customers WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Customers_Company' AND object_id = OBJECT_ID(N'[store].[Customers]'))
    CREATE INDEX IX_Customers_Company ON [store].[Customers](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Products per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'store.Products', N'CompanyId') IS NULL
    ALTER TABLE [store].[Products] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Products_Company')
    ALTER TABLE [store].[Products] WITH CHECK ADD CONSTRAINT FK_Products_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [store].[Products] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Products INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Products IS NOT NULL
        UPDATE [store].[Products] SET CompanyId = @DefaultCompanyId_Products WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_Company' AND object_id = OBJECT_ID(N'[store].[Products]'))
    CREATE INDEX IX_Products_Company ON [store].[Products](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Orders per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'store.Orders', N'CompanyId') IS NULL
    ALTER TABLE [store].[Orders] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Orders_Company')
    ALTER TABLE [store].[Orders] WITH CHECK ADD CONSTRAINT FK_Orders_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [store].[Orders] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Orders INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Orders IS NOT NULL
        UPDATE [store].[Orders] SET CompanyId = @DefaultCompanyId_Orders WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_Company' AND object_id = OBJECT_ID(N'[store].[Orders]'))
    CREATE INDEX IX_Orders_Company ON [store].[Orders](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: OrderItems per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'store.OrderItems', N'CompanyId') IS NULL
    ALTER TABLE [store].[OrderItems] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OrderItems_Company')
    ALTER TABLE [store].[OrderItems] WITH CHECK ADD CONSTRAINT FK_OrderItems_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [store].[OrderItems] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_OrderItems INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_OrderItems IS NOT NULL
        UPDATE [store].[OrderItems] SET CompanyId = @DefaultCompanyId_OrderItems WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OrderItems_Company' AND object_id = OBJECT_ID(N'[store].[OrderItems]'))
    CREATE INDEX IX_OrderItems_Company ON [store].[OrderItems](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: CartItems per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'store.CartItems', N'CompanyId') IS NULL
    ALTER TABLE [store].[CartItems] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CartItems_Company')
    ALTER TABLE [store].[CartItems] WITH CHECK ADD CONSTRAINT FK_CartItems_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [store].[CartItems] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_CartItems INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_CartItems IS NOT NULL
        UPDATE [store].[CartItems] SET CompanyId = @DefaultCompanyId_CartItems WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CartItems_Company' AND object_id = OBJECT_ID(N'[store].[CartItems]'))
    CREATE INDEX IX_CartItems_Company ON [store].[CartItems](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- =============================================
-- یکپارچه‌سازی فروشگاه با حسابداری/خزانه/انبار (الگوی طلافروشی)
-- 1) OrderLedger — دفتر بدهکار/بستانکار مشتری (کیف پول ریالی)
-- 2) StoreSettings — لینک‌های حسابداری/خزانه/انبار برای سند خودکار
-- 3) ستون‌های تسویه و سند روی Orders
-- 4) PartyId روی Customers + backfill خودکار مشتریان قدیمی
-- =============================================

-- ── OrderLedger: دفتر طرف‌حساب مشتری فروشگاه ──
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'OrderLedger')
BEGIN
    CREATE TABLE [store].[OrderLedger] (
        LedgerId    INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId   INT NOT NULL,
        CustomerId  INT NOT NULL,
        OrderId     INT NOT NULL,
        EntryDate   DATE NOT NULL,
        EntryType   NVARCHAR(30) NOT NULL,       -- OrderSale | Payment | ...
        DebitRial   DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreditRial  DECIMAL(18,2) NOT NULL DEFAULT 0,
        Description NVARCHAR(500) NULL,
        CreatedBy   NVARCHAR(100) NULL,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_OrderLedger_Customer ON [store].[OrderLedger](CompanyId, CustomerId, EntryDate);
    CREATE INDEX IX_OrderLedger_Order   ON [store].[OrderLedger](OrderId);
END

-- ── StoreSettings: لینک‌های حسابداری/خزانه/انبار ──
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'StoreSettings')
BEGIN
    CREATE TABLE [store].[StoreSettings] (
        CompanyId             INT NOT NULL PRIMARY KEY,
        InventoryWarehouseId  INT NULL,
        SalesAccountId        INT NULL,
        SalesAccountCode      NVARCHAR(30) NULL,
        SalesAccountTitle     NVARCHAR(200) NULL,
        InventoryAccountId    INT NULL,
        InventoryAccountCode  NVARCHAR(30) NULL,
        InventoryAccountTitle NVARCHAR(200) NULL,
        CashAccountId         INT NULL,
        CashAccountCode       NVARCHAR(30) NULL,
        CashAccountTitle      NVARCHAR(200) NULL,
        BankChartAccountId    INT NULL,
        BankChartAccountCode  NVARCHAR(30) NULL,
        BankChartAccountTitle NVARCHAR(200) NULL,
        CashBoxId             INT NULL,
        BankAccountId         INT NULL,
        IsEnabled             BIT NOT NULL DEFAULT 1,
        UpdatedAt             DATETIME2 NULL,
        UpdatedBy             NVARCHAR(100) NULL
    );
END

-- ── ستون‌های تسویه/سند روی Orders ──
IF COL_LENGTH(N'store.Orders', N'PaymentStatus') IS NULL
    ALTER TABLE [store].[Orders] ADD PaymentStatus NVARCHAR(30) NOT NULL CONSTRAINT DF_Orders_PaymentStatus DEFAULT N'Unpaid';
IF COL_LENGTH(N'store.Orders', N'DocumentId') IS NULL
    ALTER TABLE [store].[Orders] ADD DocumentId INT NULL;
IF COL_LENGTH(N'store.Orders', N'BalanceRial') IS NULL
    ALTER TABLE [store].[Orders] ADD BalanceRial DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_BalanceRial DEFAULT 0;
IF COL_LENGTH(N'store.Orders', N'PayCash') IS NULL
    ALTER TABLE [store].[Orders] ADD PayCash DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_PayCash DEFAULT 0;
IF COL_LENGTH(N'store.Orders', N'PayBank') IS NULL
    ALTER TABLE [store].[Orders] ADD PayBank DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_PayBank DEFAULT 0;
IF COL_LENGTH(N'store.Orders', N'ChequeNumber') IS NULL
    ALTER TABLE [store].[Orders] ADD ChequeNumber NVARCHAR(50) NULL;
IF COL_LENGTH(N'store.Orders', N'ChequeBankId') IS NULL
    ALTER TABLE [store].[Orders] ADD ChequeBankId INT NULL;
IF COL_LENGTH(N'store.Orders', N'ChequeAmount') IS NULL
    ALTER TABLE [store].[Orders] ADD ChequeAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_ChequeAmount DEFAULT 0;
IF COL_LENGTH(N'store.Orders', N'ChequeDueDate') IS NULL
    ALTER TABLE [store].[Orders] ADD ChequeDueDate DATE NULL;
GO

-- ── PartyId روی Customers (لینک به central.Parties) ──
IF COL_LENGTH(N'store.Customers', N'PartyId') IS NULL
    ALTER TABLE [store].[Customers] ADD PartyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Customers_Party')
    ALTER TABLE [store].[Customers] WITH CHECK ADD CONSTRAINT FK_Customers_Party FOREIGN KEY (PartyId) REFERENCES [central].[Parties](PartyId);
GO

-- ── Backfill: مشتریان قدیمی بدون PartyId → ساخت central.Parties + لینک حسابداری ──
-- (همان منطق خودکار طلافروشی: گروه تفصیلی از CompanyAccountSettings، کد = CUS-xxxxx)
IF EXISTS (SELECT 1 FROM [store].[Customers] WHERE PartyId IS NULL)
BEGIN
    DECLARE @BackfillCompanyId INT, @BackfillCustomerId INT, @BackfillCode NVARCHAR(50), @BackfillFullName NVARCHAR(200),
            @BackfillPartyId INT, @BackfillGrpId INT, @BackfillMoeinId INT, @BackfillNature NVARCHAR(10),
            @BackfillGrpFrom NVARCHAR(7), @BackfillNumPart INT, @BackfillDetilCode NVARCHAR(7),
            @BackfillExistingDetilId INT;
    DECLARE curBackfill CURSOR LOCAL FAST_FORWARD FOR
        SELECT CustomerId, CompanyId, CustomerCode, FullName FROM [store].[Customers] WHERE PartyId IS NULL;
    OPEN curBackfill;
    FETCH NEXT FROM curBackfill INTO @BackfillCustomerId, @BackfillCompanyId, @BackfillCode, @BackfillFullName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @BackfillCode IS NULL OR @BackfillCode = N''
            SET @BackfillCode = N'CUS-' + RIGHT(N'00000' + CAST(@BackfillCustomerId AS NVARCHAR(10)), 5);
        INSERT INTO [central].[Parties]
            (CompanyId, PartyCode, PartyType, FullName, Phone, Email, IsActive, CreatedAt, CreatedBy)
        VALUES (@BackfillCompanyId, @BackfillCode, N'Customer', @BackfillFullName, NULL, NULL, 1, SYSUTCDATETIME(), N'system');
        SET @BackfillPartyId = CAST(SCOPE_IDENTITY() AS INT);
        UPDATE [store].[Customers] SET PartyId = @BackfillPartyId WHERE CustomerId = @BackfillCustomerId;
        -- لینک حسابداری خودکار (اگر گروه تفصیلی مشتری در تنظیمات شرکت موجود باشد)
        SET @BackfillGrpId = (SELECT CustomerAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId = @BackfillCompanyId);
        SET @BackfillMoeinId = (SELECT DefaultMoeinId FROM [accounting].[AccountGroups] WHERE AccountGroupId = @BackfillGrpId AND CompanyId = @BackfillCompanyId AND IsDeleted = 0 AND IsActive = 1);
        SET @BackfillNature = (SELECT DefaultNature FROM [accounting].[AccountGroups] WHERE AccountGroupId = @BackfillGrpId AND CompanyId = @BackfillCompanyId);
        SET @BackfillGrpFrom = (SELECT FromCode FROM [accounting].[AccountGroups] WHERE AccountGroupId = @BackfillGrpId AND CompanyId = @BackfillCompanyId);
        SET @BackfillNumPart = TRY_CONVERT(INT, RIGHT(@BackfillCode, 5));
        SET @BackfillDetilCode = CASE WHEN @BackfillNumPart IS NOT NULL AND @BackfillGrpFrom IS NOT NULL
            THEN RIGHT(N'0000000' + CONVERT(NVARCHAR(7), CONVERT(INT, @BackfillGrpFrom) + @BackfillNumPart - 1), 7)
            ELSE @BackfillGrpFrom END;
        IF @BackfillGrpId IS NOT NULL AND @BackfillMoeinId IS NOT NULL AND @BackfillDetilCode IS NOT NULL
        BEGIN
            SET @BackfillExistingDetilId = (SELECT TOP 1 d.DetilId FROM [accounting].[BaseDetil] d
                WHERE d.CompanyId = @BackfillCompanyId AND d.DetilCode = @BackfillDetilCode AND d.IsDeleted = 0);
            IF @BackfillExistingDetilId IS NULL
            BEGIN
                INSERT INTO [accounting].[BaseDetil]
                    (DetilCode, Title, [Description], AccountGroupId, AccountNature, IsActive, CreatedAt, CreatedBy, CompanyId)
                VALUES (@BackfillDetilCode, @BackfillFullName, N'تفصیلی خودکار فروشگاه',
                        @BackfillGrpId, ISNULL(@BackfillNature, N'Both'), 1, SYSUTCDATETIME(), N'system', @BackfillCompanyId);
                SET @BackfillExistingDetilId = CAST(SCOPE_IDENTITY() AS INT);
                INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, [Description], IsActive, CreatedAt, CreatedBy, CompanyId)
                VALUES (@BackfillExistingDetilId, @BackfillMoeinId, N'لینک خودکار ' + @BackfillDetilCode, 1, SYSUTCDATETIME(), N'system', @BackfillCompanyId);
            END
            IF NOT EXISTS (SELECT 1 FROM [treasury].[PartyLi
ks] WHERE CompanyId = @BackfillCompanyId AND PartyId = @BackfillPartyId)
                INSERT INTO [treasury].[PartyLinks]
                    (CompanyId, PartyId, PartyType, DetailLinkId, DetailAccountCode, CreatedAt, CreatedBy)
                VALUES (@BackfillCompanyId, @BackfillPartyId, N'Customer', @BackfillExistingDetilId, @BackfillDetilCode, SYSUTCDATETIME(), N'system');
        END
        FETCH NEXT FROM curBackfill INTO @BackfillCustomerId, @BackfillCompanyId, @BackfillCode, @BackfillFullName;
    END
    CLOSE curBackfill; DEALLOCATE curBackfill;
END
GO

-- =============================================================
-- WAVE 1: Multi-Store + State Machine سفارش
--   هر فروشگاه به یک انبار inventory.Warehouses متصل است؛
--   موجودی قابل فروش همیشه از انبار خوانده می‌شود.
-- =============================================================

-- ── Stores ──────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Stores')
BEGIN
    CREATE TABLE [store].[Stores] (
        StoreId          INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId        INT NOT NULL,
        StoreCode        NVARCHAR(30)  NOT NULL,
        Title            NVARCHAR(200) NOT NULL,
        StoreType        NVARCHAR(20)  NOT NULL CONSTRAINT DF_Stores_Type DEFAULT N'Physical', -- Physical | Online | Hybrid
        WarehouseId      INT           NULL,                -- انبار اختصاصی (inventory.Warehouses)
        ManagerUserId    INT           NULL,
        ManagerName      NVARCHAR(200) NULL,
        Phone            NVARCHAR(30)  NULL,
        Email            NVARCHAR(120) NULL,
        Address          NVARCHAR(500) NULL,
        WorkingHours     NVARCHAR(300) NULL,
        Description      NVARCHAR(500) NULL,
        LogoUrl          NVARCHAR(500) NULL,
        BannerUrl        NVARCHAR(500) NULL,
        OnlineEnabled    BIT NOT NULL CONSTRAINT DF_Stores_Online DEFAULT 0,
        IsActive         BIT NOT NULL CONSTRAINT DF_Stores_IsActive DEFAULT 1,
        IsDeleted        BIT NOT NULL CONSTRAINT DF_Stores_IsDeleted DEFAULT 0,
        CreatedAt        DATETIME2 NOT NULL CONSTRAINT DF_Stores_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt        DATETIME2 NULL,
        CreatedBy        NVARCHAR(100) NULL,
        UpdatedBy        NVARCHAR(100) NULL,
        CONSTRAINT FK_Stores_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Stores_Company_Code' AND object_id = OBJECT_ID(N'[store].[Stores]'))
    CREATE UNIQUE INDEX UX_Stores_Company_Code ON [store].[Stores](CompanyId, StoreCode) WHERE IsDeleted = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Stores_Company' AND object_id = OBJECT_ID(N'[store].[Stores]'))
    CREATE INDEX IX_Stores_Company ON [store].[Stores](CompanyId) WHERE IsDeleted = 0;
GO

-- ── StoreId روی Customers / Orders / Products ──────────────
IF COL_LENGTH(N'store.Customers', N'StoreId') IS NULL
    ALTER TABLE [store].[Customers] ADD StoreId INT NULL;
GO
IF COL_LENGTH(N'store.Orders', N'StoreId') IS NULL
    ALTER TABLE [store].[Orders] ADD StoreId INT NULL;
GO
IF COL_LENGTH(N'store.Products', N'StoreId') IS NULL
    ALTER TABLE [store].[Products] ADD StoreId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_Store' AND object_id = OBJECT_ID(N'[store].[Orders]'))
    CREATE INDEX IX_Orders_Store ON [store].[Orders](StoreId) WHERE StoreId IS NOT NULL;
GO

-- ── StoreSettings → per-store (migration: CompanyId PK می‌ماند؛
--    StoreId اختیاری اضافه می‌شود تا تنظیمات مالی برای فروشگاه خاص هم ممکن باشد) ──
IF COL_LENGTH(N'store.StoreSettings', N'StoreId') IS NULL
    ALTER TABLE [store].[StoreSettings] ADD StoreId INT NULL;
GO

-- ── State Machine سفارش: تاریخچهٔ وضعیت‌ها ──────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'OrderStatusHistory')
BEGIN
    CREATE TABLE [store].[OrderStatusHistory] (
        HistoryId    INT IDENTITY(1,1) PRIMARY KEY,
        OrderId      INT NOT NULL,
        FromStatus   NVARCHAR(30) NULL,
        ToStatus     NVARCHAR(30) NOT NULL,
        Reason       NVARCHAR(500) NULL,
        ChangedBy    NVARCHAR(100) NULL,
        CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_OrderStatusHistory_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_OSH_Orders FOREIGN KEY (OrderId) REFERENCES [store].[Orders](OrderId)
    );
    CREATE INDEX IX_OSH_Order ON [store].[OrderStatusHistory](OrderId, HistoryId);
END
GO

-- Backfill: برای سفارش‌های موجود یک رکورد تاریخچهٔ اولیه بساز
IF OBJECT_ID(N'store.OrderStatusHistory', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM [store].[OrderStatusHistory])
BEGIN
    INSERT INTO [store].[OrderStatusHistory] (OrderId, FromStatus, ToStatus, Reason, ChangedBy)
    SELECT OrderId, NULL, Status, N'Backfill', N'system'
    FROM [store].[Orders];
END
GO

-- ── جدول انتقال‌های مجاز State Machine ──────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'OrderStatusTransitions')
BEGIN
    CREATE TABLE [store].[OrderStatusTransitions] (
        FromStatus NVARCHAR(30) NOT NULL,
        ToStatus   NVARCHAR(30) NOT NULL,
        CONSTRAINT PK_OrderStatusTransitions PRIMARY KEY (FromStatus, ToStatus)
    );
    INSERT INTO [store].[OrderStatusTransitions] (FromStatus, ToStatus) VALUES
        (N'Placed',    N'Reserved'),
        (N'Placed',    N'Cancelled'),
        (N'Placed',    N'Rejected'),
        (N'Reserved',  N'Invoiced'),
        (N'Reserved',  N'Cancelled'),
        (N'Reserved',  N'Rejected'),
        (N'Invoiced',  N'Completed'),
        (N'Invoiced',  N'Cancelled'),   -- فقط با مجوز + در OrderStatusChange کنترل می‌شود
        (N'Invoiced',  N'Returned'),
        (N'Completed', N'Returned');
END
GO

-- =============================================================
-- WAVE 2: Product Catalog (برند، درخت دسته، ویژگی داینامیک، تنوع، تصاویر)
-- =============================================================

-- ── Brands ──────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Brands')
BEGIN
    CREATE TABLE [store].[Brands] (
        BrandId    INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId  INT NOT NULL,
        BrandCode  NVARCHAR(30)  NOT NULL,
        Title      NVARCHAR(200) NOT NULL,
        LogoUrl    NVARCHAR(500) NULL,
        [Description] NVARCHAR(500) NULL,
        IsActive   BIT NOT NULL CONSTRAINT DF_Brands_Active DEFAULT 1,
        IsDeleted  BIT NOT NULL CONSTRAINT DF_Brands_Deleted DEFAULT 0,
        CreatedAt  DATETIME2 NOT NULL CONSTRAINT DF_Brands_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt  DATETIME2 NULL,
        CreatedBy  NVARCHAR(100) NULL,
        UpdatedBy  NVARCHAR(100) NULL,
        CONSTRAINT FK_Brands_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Brands_Company_Code' AND object_id = OBJECT_ID(N'[store].[Brands]'))
    CREATE UNIQUE INDEX UX_Brands_Company_Code ON [store].[Brands](CompanyId, BrandCode) WHERE IsDeleted = 0;
GO

-- ── ProductCategories: درختی شدن (ParentId) ────────────────
IF COL_LENGTH(N'store.ProductCategories', N'ParentId') IS NULL
    ALTER TABLE [store].[ProductCategories] ADD ParentId INT NULL;
GO
IF COL_LENGTH(N'store.ProductCategories', N'BrandId') IS NULL
    ALTER TABLE [store].[ProductCategories] ADD BrandId INT NULL;
GO

-- ── Products: گسترش کاتالوگ ────────────────────────────────
IF COL_LENGTH(N'store.Products', N'SKU') IS NULL
    ALTER TABLE [store].[Products] ADD SKU NVARCHAR(50) NULL;
IF COL_LENGTH(N'store.Products', N'Barcode') IS NULL
    ALTER TABLE [store].[Products] ADD Barcode NVARCHAR(50) NULL;
IF COL_LENGTH(N'store.Products', N'CategoryId') IS NULL
    ALTER TABLE [store].[Products] ADD CategoryId INT NULL;
IF COL_LENGTH(N'store.Products', N'BrandId') IS NULL
    ALTER TABLE [store].[Products] ADD BrandId INT NULL;
IF COL_LENGTH(N'store.Products', N'UnitId') IS NULL
    ALTER TABLE [store].[Products] ADD UnitId INT NULL;
IF COL_LENGTH(N'store.Products', N'ShortTitle') IS NULL
    ALTER TABLE [store].[Products] ADD ShortTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'store.Products', N'EnglishTitle') IS NULL
    ALTER TABLE [store].[Products] ADD EnglishTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'store.Products', N'Slug') IS NULL
    ALTER TABLE [store].[Products] ADD Slug NVARCHAR(220) NULL;
IF COL_LENGTH(N'store.Products', N'SeoTitle') IS NULL
    ALTER TABLE [store].[Products] ADD SeoTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'store.Products', N'MetaDescription') IS NULL
    ALTER TABLE [store].[Products] ADD MetaDescription NVARCHAR(500) NULL;
IF COL_LENGTH(N'store.Products', N'LongDescription') IS NULL
    ALTER TABLE [store].[Products] ADD LongDescription NVARCHAR(MAX) NULL;
IF COL_LENGTH(N'store.Products', N'Weight') IS NULL
    ALTER TABLE [store].[Products] ADD Weight DECIMAL(18,3) NULL;
IF COL_LENGTH(N'store.Products', N'Dimensions') IS NULL
    ALTER TABLE [store].[Products] ADD Dimensions NVARCHAR(100) NULL;
IF COL_LENGTH(N'store.Products', N'CostPrice') IS NULL
    ALTER TABLE [store].[Products] ADD CostPrice DECIMAL(18,2) NULL;
IF COL_LENGTH(N'store.Products', N'OnlinePrice') IS NULL
    ALTER TABLE [store].[Products] ADD OnlinePrice DECIMAL(18,2) NULL;
IF COL_LENGTH(N'store.Products', N'DiscountPrice') IS NULL
    ALTER TABLE [store].[Products] ADD DiscountPrice DECIMAL(18,2) NULL;
IF COL_LENGTH(N'store.Products', N'DiscountFrom') IS NULL
    ALTER TABLE [store].[Products] ADD DiscountFrom DATETIME2 NULL;
IF COL_LENGTH(N'store.Products', N'DiscountTo') IS NULL
    ALTER TABLE [store].[Products] ADD DiscountTo DATETIME2 NULL;
IF COL_LENGTH(N'store.Products', N'MainImageUrl') IS NULL
    ALTER TABLE [store].[Products] ADD MainImageUrl NVARCHAR(500) NULL;
IF COL_LENGTH(N'store.Products', N'HasVariants') IS NULL
    ALTER TABLE [store].[Products] ADD HasVariants BIT NOT NULL CONSTRAINT DF_Products_HasVariants DEFAULT 0;
IF COL_LENGTH(N'store.Products', N'UpdatedAt') IS NULL
    ALTER TABLE [store].[Products] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'store.Products', N'UpdatedBy') IS NULL
    ALTER TABLE [store].[Products] ADD UpdatedBy NVARCHAR(100) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_Category' AND object_id = OBJECT_ID(N'[store].[Products]'))
    CREATE INDEX IX_Products_Category ON [store].[Products](CategoryId) WHERE CategoryId IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_Barcode' AND object_id = OBJECT_ID(N'[store].[Products]'))
    CREATE INDEX IX_Products_Barcode ON [store].[Products](Barcode) WHERE Barcode IS NOT NULL;
GO

-- ── ProductImages ──────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'ProductImages')
BEGIN
    CREATE TABLE [store].[ProductImages] (
        ImageId    INT IDENTITY(1,1) PRIMARY KEY,
        ProductId  INT NOT NULL,
        ImageUrl   NVARCHAR(500) NOT NULL,
        AltText    NVARCHAR(200) NULL,
        SortOrder  INT NOT NULL CONSTRAINT DF_ProductImages_Sort DEFAULT 0,
        IsMain     BIT NOT NULL CONSTRAINT DF_ProductImages_Main DEFAULT 0,
        CreatedAt  DATETIME2 NOT NULL CONSTRAINT DF_ProductImages_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_ProductImages_Product FOREIGN KEY (ProductId) REFERENCES [store].[Products](ProductId)
    );
    CREATE INDEX IX_ProductImages_Product ON [store].[ProductImages](ProductId, SortOrder);
END
GO

-- ── AttributeGroups / Attributes / AttributeValues / ProductAttributes ──
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'AttributeGroups')
BEGIN
    CREATE TABLE [store].[AttributeGroups] (
        AttributeGroupId INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId        INT NOT NULL,
        Title            NVARCHAR(200) NOT NULL,   -- مثلا «مشخصات موبایل»، «سایز لباس»
        SortOrder        INT NOT NULL CONSTRAINT DF_AttrGroups_Sort DEFAULT 0,
        IsActive         BIT NOT NULL CONSTRAINT DF_AttrGroups_Active DEFAULT 1,
        IsDeleted        BIT NOT NULL CONSTRAINT DF_AttrGroups_Deleted DEFAULT 0,
        CreatedAt        DATETIME2 NOT NULL CONSTRAINT DF_AttrGroups_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_AttrGroups_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Attributes')
BEGIN
    CREATE TABLE [store].[Attributes] (
        AttributeId       INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId         INT NOT NULL,
        AttributeGroupId  INT NULL,
        Title             NVARCHAR(200) NOT NULL,   -- «RAM»، «سایز»، «رنگ»
        DataType          NVARCHAR(20) NOT NULL CONSTRAINT DF_Attributes_Type DEFAULT N'Text', -- Text | Number | Boolean | List
        Unit              NVARCHAR(30) NULL,        -- «GB»، «اینچ»
        IsVariantFacet    BIT NOT NULL CONSTRAINT DF_Attributes_Facet DEFAULT 0,  -- رنگ/سایز → Variant
        SortOrder         INT NOT NULL CONSTRAINT DF_Attributes_Sort DEFAULT 0,
        IsActive          BIT NOT NULL CONSTRAINT DF_Attributes_Active DEFAULT 1,
        IsDeleted         BIT NOT NULL CONSTRAINT DF_Attributes_Deleted DEFAULT 0,
        CreatedAt         DATETIME2 NOT NULL CONSTRAINT DF_Attributes_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Attributes_Group FOREIGN KEY (AttributeGroupId) REFERENCES [store].[AttributeGroups](AttributeGroupId),
        CONSTRAINT FK_Attributes_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_Attributes_Company ON [store].[Attributes](CompanyId, IsDeleted);
END
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'ProductAttributes')
BEGIN
    CREATE TABLE [store].[ProductAttributes] (
        ProductAttributeId INT IDENTITY(1,1) PRIMARY KEY,
        ProductId          INT NOT NULL,
        AttributeId        INT NOT NULL,
        ValueText          NVARCHAR(500) NULL,
        SortOrder          INT NOT NULL CONSTRAINT DF_ProdAttr_Sort DEFAULT 0,
        CONSTRAINT FK_ProdAttr_Product   FOREIGN KEY (ProductId)   REFERENCES [store].[Products](ProductId),
        CONSTRAINT FK_ProdAttr_Attribute FOREIGN KEY (AttributeId) REFERENCES [store].[Attributes](AttributeId)
    );
    CREATE INDEX IX_ProdAttr_Product ON [store].[ProductAttributes](ProductId);
    CREATE INDEX IX_ProdAttr_Attribute ON [store].[ProductAttributes](AttributeId);
END
GO

-- ── ProductVariants ────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'ProductVariants')
BEGIN
    CREATE TABLE [store].[ProductVariants] (
        VariantId     INT IDENTITY(1,1) PRIMARY KEY,
        ProductId     INT NOT NULL,
        VariantCode   NVARCHAR(50)  NOT NULL,
        Title         NVARCHAR(200) NOT NULL,
        Barcode       NVARCHAR(50)  NULL,
        Price         DECIMAL(18,2) NOT NULL CONSTRAINT DF_Variants_Price DEFAULT 0,
        DiscountPrice DECIMAL(18,2) NULL,
        Weight        DECIMAL(18,3) NULL,
        ImageUrl      NVARCHAR(500) NULL,
        IsActive      BIT NOT NULL CONSTRAINT DF_Variants_Active DEFAULT 1,
        IsDeleted     BIT NOT NULL CONSTRAINT DF_Variants_Deleted DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_Variants_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL,
        ItemCode      NVARCHAR(50)  NULL,
        CONSTRAINT FK_Variants_Product FOREIGN KEY (ProductId) REFERENCES [store].[Products](ProductId)
    );
    CREATE UNIQUE INDEX UX_Variants_Product_Code ON [store].[ProductVariants](ProductId, VariantCode) WHERE IsDeleted = 0;
END
GO

-- VariantAttributes
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'VariantAttributes')
BEGIN
    CREATE TABLE [store].[VariantAttributes] (
        VariantId   INT NOT NULL,
        AttributeId INT NOT NULL,
        ValueText   NVARCHAR(200) NOT NULL,
        CONSTRAINT PK_VariantAttributes PRIMARY KEY (VariantId, AttributeId),
        CONSTRAINT FK_VarAttr_Variant   FOREIGN KEY (VariantId)   REFERENCES [store].[ProductVariants](VariantId),
        CONSTRAINT FK_VarAttr_Attribute FOREIGN KEY (AttributeId) REFERENCES [store].[Attributes](AttributeId)
    );
END
GO
GO
-- =============================================================
-- WAVE 3: قیمت‌گذاری per-store + تخفیف‌ها + کوپن
--   Existing = کلید یکتا (StoreId, ProductId)؛ Available = StockQty − رزرو فعال.
--   منبع حقیقت قیمت: ProductPrices؛ قیمت Products.Price فقط fallback است.
-- =============================================================

-- ── PriceLists (Retail/Wholesale/VIP/...) ───────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'PriceLists')
BEGIN
    CREATE TABLE [store].[PriceLists] (
        PriceListId  INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId    INT NOT NULL,
        Code         NVARCHAR(30)  NOT NULL,
        Title        NVARCHAR(200) NOT NULL,
        StoreId      INT NULL,                -- NULL = همهٔ فروشگاه‌ها
        CurrencyCode NVARCHAR(10)  NOT NULL CONSTRAINT DF_PriceLists_Curr DEFAULT N'IRR',
        IsActive     BIT NOT NULL CONSTRAINT DF_PriceLists_Active DEFAULT 1,
        IsDeleted    BIT NOT NULL CONSTRAINT DF_PriceLists_Deleted DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_PriceLists_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL,
        CreatedBy    NVARCHAR(100) NULL,
        UpdatedBy    NVARCHAR(100) NULL,
        CONSTRAINT FK_PriceLists_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_PriceLists_Company_Code' AND object_id = OBJECT_ID(N'[store].[PriceLists]'))
    CREATE UNIQUE INDEX UX_PriceLists_Company_Code ON [store].[PriceLists](CompanyId, Code) WHERE IsDeleted = 0;
GO

-- ── ProductPrices: قیمت هر محصول در هر لیست/فروشگاه ─────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'ProductPrices')
BEGIN
    CREATE TABLE [store].[ProductPrices] (
        PriceId      INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId    INT NOT NULL,
        PriceListId  INT NOT NULL,
        ProductId    INT NOT NULL,
        StoreId      INT NULL,                -- NULL = همهٔ فروشگاه‌های لیست
        Price        DECIMAL(18,2) NOT NULL,
        FromDate     DATE NULL,
        ToDate       DATE NULL,
        MinQty       DECIMAL(18,3) NOT NULL CONSTRAINT DF_ProdPrices_MinQty DEFAULT 1,
        IsDeleted    BIT NOT NULL CONSTRAINT DF_ProdPrices_Deleted DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_ProdPrices_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL,
        CreatedBy    NVARCHAR(100) NULL,
        UpdatedBy    NVARCHAR(100) NULL,
        CONSTRAINT FK_ProdPrices_List    FOREIGN KEY (PriceListId) REFERENCES [store].[PriceLists](PriceListId),
        CONSTRAINT FK_ProdPrices_Product FOREIGN KEY (ProductId)   REFERENCES [store].[Products](ProductId)
    );
    CREATE INDEX IX_ProdPrices_Lookup ON [store].[ProductPrices](CompanyId, ProductId, PriceListId) WHERE IsDeleted = 0;
END
GO

-- ── Promotions (کمپین تخفیف) ────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Promotions')
BEGIN
    CREATE TABLE [store].[Promotions] (
        PromotionId   INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId     INT NOT NULL,
        Code          NVARCHAR(30)  NOT NULL,
        Title         NVARCHAR(200) NOT NULL,
        StoreId       INT NULL,                -- NULL = همهٔ فروشگاه‌ها
        ProductId     INT NULL,                -- NULL = همهٔ محصولات
        CategoryId    INT NULL,                -- NULL = همهٔ دسته‌ها
        DiscountType  NVARCHAR(10)  NOT NULL CONSTRAINT DF_Promo_Type DEFAULT N'Percent', -- Percent | Amount
        DiscountValue DECIMAL(18,2) NOT NULL CONSTRAINT DF_Promo_Value DEFAULT 0,
        FromDate      DATETIME2 NOT NULL CONSTRAINT DF_Promo_From DEFAULT SYSUTCDATETIME(),
        ToDate        DATETIME2 NOT NULL CONSTRAINT DF_Promo_To DEFAULT DATEADD(DAY, 30, SYSUTCDATETIME()),
        MinOrderTotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_Promo_MinTotal DEFAULT 0,
        IsActive      BIT NOT NULL CONSTRAINT DF_Promo_Active DEFAULT 1,
        IsDeleted     BIT NOT NULL CONSTRAINT DF_Promo_Deleted DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_Promo_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL,
        CreatedBy     NVARCHAR(100) NULL,
        UpdatedBy     NVARCHAR(100) NULL,
        CONSTRAINT FK_Promo_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Promo_Company_Code' AND object_id = OBJECT_ID(N'[store].[Promotions]'))
    CREATE UNIQUE INDEX UX_Promo_Company_Code ON [store].[Promotions](CompanyId, Code) WHERE IsDeleted = 0;
GO

-- ── Coupons (کد تخفیف قابل‌اعمال در سبد) ─────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'Coupons')
BEGIN
    CREATE TABLE [store].[Coupons] (
        CouponId      INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId     INT NOT NULL,
        Code          NVARCHAR(50)  NOT NULL,
        Title         NVARCHAR(200) NOT NULL,
        StoreId       INT NULL,                -- NULL = همهٔ فروشگاه‌ها
        DiscountType  NVARCHAR(10)  NOT NULL CONSTRAINT DF_Coupon_Type DEFAULT N'Percent', -- Percent | Amount
        DiscountValue DECIMAL(18,2) NOT NULL CONSTRAINT DF_Coupon_Value DEFAULT 0,
        MaxDiscount   DECIMAL(18,2) NULL,      -- سقف مبلغ تخفیف (برای درصدی)
        MinOrderTotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_Coupon_MinTotal DEFAULT 0,
        UsageLimit    INT NULL,                -- NULL = بی‌نهایت
        UsedCount     INT NOT NULL CONSTRAINT DF_Coupon_Used DEFAULT 0,
        PerCustomerLimit INT NULL,             -- سقف استفادهٔ هر مشتری
        FromDate      DATETIME2 NOT NULL CONSTRAINT DF_Coupon_From DEFAULT SYSUTCDATETIME(),
        ToDate        DATETIME2 NOT NULL CONSTRAINT DF_Coupon_To DEFAULT DATEADD(DAY, 30, SYSUTCDATETIME()),
        IsActive      BIT NOT NULL CONSTRAINT DF_Coupon_Active DEFAULT 1,
        IsDeleted     BIT NOT NULL CONSTRAINT DF_Coupon_Deleted DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL CONSTRAINT DF_Coupon_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL,
        CreatedBy     NVARCHAR(100) NULL,
        UpdatedBy     NVARCHAR(100) NULL,
        CONSTRAINT FK_Coupon_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Coupon_Company_Code' AND object_id = OBJECT_ID(N'[store].[Coupons]'))
    CREATE UNIQUE INDEX UX_Coupon_Company_Code ON [store].[Coupons](CompanyId, Code) WHERE IsDeleted = 0;
GO

-- ── Orders: ستون‌های تخفیف ──────────────────────────────────
IF COL_LENGTH(N'store.Orders', N'DiscountTotal') IS NULL
    ALTER TABLE [store].[Orders] ADD DiscountTotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_DiscTotal DEFAULT 0;
IF COL_LENGTH(N'store.Orders', N'CouponId') IS NULL
    ALTER TABLE [store].[Orders] ADD CouponId INT NULL;
IF COL_LENGTH(N'store.Orders', N'PromotionId') IS NULL
    ALTER TABLE [store].[Orders] ADD PromotionId INT NULL;
IF COL_LENGTH(N'store.Orders', N'PriceListId') IS NULL
    ALTER TABLE [store].[Orders] ADD PriceListId INT NULL;
IF COL_LENGTH(N'store.Orders', N'GrossTotal') IS NULL
    ALTER TABLE [store].[Orders] ADD GrossTotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_GrossTotal DEFAULT 0;
GO
-- سند/مانده‌ها بر GrossTotal − DiscountTotal بنا می‌شوند؛ Backfill برای ردیف‌های موجود:
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'store.Orders') AND name = N'GrossTotal')
   AND EXISTS (SELECT 1 FROM [store].[Orders] WHERE GrossTotal = 0 AND TotalAmount > 0)
    UPDATE [store].[Orders] SET GrossTotal = TotalAmount, DiscountTotal = 0
    WHERE GrossTotal = 0 AND TotalAmount > 0;
GO

-- ── CouponRedemptions: اتمی و idempotent با سفارش ───────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'store' AND t.name = N'CouponRedemptions')
BEGIN
    CREATE TABLE [store].[CouponRedemptions] (
        RedemptionId INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId    INT NOT NULL,
        CouponId     INT NOT NULL,
        OrderId      INT NOT NULL,
        CustomerId   INT NOT NULL,
        DiscountAmt  DECIMAL(18,2) NOT NULL,
        CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_CouponRed_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_CouponRed_Coupon FOREIGN KEY (CouponId) REFERENCES [store].[Coupons](CouponId),
        CONSTRAINT FK_CouponRed_Order  FOREIGN KEY (OrderId)  REFERENCES [store].[Orders](OrderId)
    );
    CREATE UNIQUE INDEX UX_CouponRed_Order ON [store].[CouponRedemptions](OrderId, CouponId);
END
GO
