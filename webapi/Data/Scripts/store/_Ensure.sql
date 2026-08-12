-- =============================================
-- webapi/Data/Scripts/store/_Ensure.sql
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
