-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/store/_Ensure.sql
-- Schema: store (فروشگاه اینترنتی)
-- Endpoint: execute (startup)
-- =============================================
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
