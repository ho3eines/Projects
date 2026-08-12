-- =============================================
-- TarazinApp/Data/Scripts/central/_Ensure.sql
-- Schema: central
-- Endpoint: execute (startup only)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'central')
    EXEC(N'CREATE SCHEMA [central]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Users')
BEGIN
    CREATE TABLE [central].[Users] (
        UserId        INT IDENTITY(1,1) PRIMARY KEY,
        Username      NVARCHAR(80)  NOT NULL UNIQUE,
        PasswordHash  NVARCHAR(300) NOT NULL,
        DisplayName   NVARCHAR(120) NOT NULL,
        Role          NVARCHAR(40)  NOT NULL DEFAULT N'User',
        IsActive      BIT NOT NULL DEFAULT 1,
        IsDeleted     BIT NOT NULL DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL,
        CreatedBy     NVARCHAR(100) NULL,
        UpdatedBy     NVARCHAR(100) NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Sessions')
BEGIN
    CREATE TABLE [central].[Sessions] (
        TokenHash               CHAR(64)       NOT NULL PRIMARY KEY,
        ProjectGuid             UNIQUEIDENTIFIER NOT NULL,
        SchemaName              NVARCHAR(50)   NOT NULL,
        ProjectName             NVARCHAR(80)   NOT NULL,
        EncryptionKeyProtected  NVARCHAR(500)  NOT NULL,
        UserId                  INT NULL,
        ClientId                NVARCHAR(80) NULL,
        ExpiresAt               DATETIME2      NOT NULL,
        CreatedAt               DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Sessions_Users FOREIGN KEY (UserId) REFERENCES [central].[Users](UserId)
    );
    CREATE INDEX IX_Sessions_ExpiresAt ON [central].[Sessions](ExpiresAt);
END

-- Audit trail (PRD §5, ADR-002): hash-chained, tamper-evident.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'AuditLog')
BEGIN
    CREATE TABLE [central].[AuditLog] (
        AuditId     BIGINT IDENTITY(1,1) PRIMARY KEY,
        PrevHash    CHAR(64) NOT NULL,
        RowHash     CHAR(64) NOT NULL,
        SchemaName  NVARCHAR(100) NOT NULL,
        ScriptName  NVARCHAR(200) NOT NULL,
        Parameters  NVARCHAR(MAX) NULL,
        UserTokenId NVARCHAR(100) NULL,
        RequestId   NVARCHAR(100) NULL,
        Outcome     NVARCHAR(20) NOT NULL DEFAULT N'Success',
        Error       NVARCHAR(MAX) NULL,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_AuditLog_CreatedAt ON [central].[AuditLog](CreatedAt);
    CREATE INDEX IX_AuditLog_Schema ON [central].[AuditLog](SchemaName, CreatedAt);
END

-- Contract: Party (Core owner) — v2 adds NationalId.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Parties')
BEGIN
    CREATE TABLE [central].[Parties] (
        PartyId     INT IDENTITY(1,1) PRIMARY KEY,
        PartyCode   NVARCHAR(50) NOT NULL UNIQUE,
        PartyType   NVARCHAR(30) NOT NULL DEFAULT N'Customer',   -- Customer | Vendor | Employee
        FullName    NVARCHAR(200) NOT NULL,
        NationalId  NVARCHAR(20) NULL,                            -- v2 field
        Phone       NVARCHAR(30) NULL,
        Email       NVARCHAR(120) NULL,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL,
        UpdatedBy   NVARCHAR(100) NULL
    );
    CREATE INDEX IX_Parties_Type ON [central].[Parties](PartyType, IsDeleted);
END

-- محتویات وبسایت مرکزی (پلتفرم مشترک): اخبار، بلاگ، گالری.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'News')
BEGIN
    CREATE TABLE [central].[News] (
        NewsId      INT IDENTITY(1,1) PRIMARY KEY,
        Title       NVARCHAR(200) NOT NULL,
        Summary     NVARCHAR(1000) NULL,
        Body        NVARCHAR(MAX) NULL,
        ImageUrl    NVARCHAR(500) NULL,
        PublishedAt DATE NULL,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'BlogPosts')
BEGIN
    CREATE TABLE [central].[BlogPosts] (
        PostId      INT IDENTITY(1,1) PRIMARY KEY,
        Title       NVARCHAR(200) NOT NULL,
        Slug        NVARCHAR(200) NULL,
        Body        NVARCHAR(MAX) NULL,
        Author      NVARCHAR(100) NULL,
        Tags        NVARCHAR(500) NULL,
        PublishedAt DATE NULL,
        IsActive    BIT NOT NULL DEFAULT 1,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'GalleryItems')
BEGIN
    CREATE TABLE [central].[GalleryItems] (
        GalleryItemId INT IDENTITY(1,1) PRIMARY KEY,
        Title         NVARCHAR(200) NOT NULL,
        ImageUrl      NVARCHAR(500) NULL,
        Caption       NVARCHAR(500) NULL,
        SortOrder     INT NOT NULL DEFAULT 0,
        IsActive      BIT NOT NULL DEFAULT 1,
        IsDeleted     BIT NOT NULL DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(100) NULL
    );
END
