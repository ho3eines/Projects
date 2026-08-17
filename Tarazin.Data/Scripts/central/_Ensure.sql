-- =============================================
-- Tarazin.Data/Scripts/central/_Ensure.sql
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
        UpdatedAt     DATETIME2 NULL,
        CreatedBy     NVARCHAR(100) NULL,
        UpdatedBy     NVARCHAR(100) NULL
    );
END

-- ─────────────────────────────────────────────────────────────
-- Access control (RBAC): permissions, roles, role→permission.
-- ─────────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Permissions')
BEGIN
    CREATE TABLE [central].[Permissions] (
        PermissionId  INT IDENTITY(1,1) PRIMARY KEY,
        PermissionKey NVARCHAR(80)  NOT NULL UNIQUE,
        Title         NVARCHAR(160) NOT NULL,
        ModuleKey     NVARCHAR(50)  NOT NULL,              -- accounting | system | ...
        IsDeleted     BIT NOT NULL DEFAULT 0,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL
    );
    CREATE INDEX IX_Permissions_Module ON [central].[Permissions](ModuleKey, IsDeleted);
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Roles')
BEGIN
    CREATE TABLE [central].[Roles] (
        RoleId      INT IDENTITY(1,1) PRIMARY KEY,
        RoleKey     NVARCHAR(40)  NOT NULL UNIQUE,
        Title       NVARCHAR(120) NOT NULL,
        Description NVARCHAR(300) NULL,
        IsSystem    BIT NOT NULL DEFAULT 0,
        IsDeleted   BIT NOT NULL DEFAULT 0,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL,
        UpdatedBy   NVARCHAR(100) NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'RolePermissions')
BEGIN
    CREATE TABLE [central].[RolePermissions] (
        RoleId       INT NOT NULL,
        PermissionId INT NOT NULL,
        CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionId),
        CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId)
            REFERENCES [central].[Roles](RoleId),
        CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId)
            REFERENCES [central].[Permissions](PermissionId)
    );
END

-- ─────────────────────────────────────────────────────────────
-- Migrations (idempotent) — برای دیتابیس‌های ساخته‌شده قبل از RBAC
-- و تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy.
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'central.Users', N'RoleId') IS NULL
    ALTER TABLE [central].[Users] ADD RoleId INT NULL;
GO
-- ⚠ مرز batch لازم است: ستون RoleId در batch قبلی اضافه می‌شود و constraint
--   پایین‌تر به آن اشاره دارد. SQL Server کل batch را قبل از اجرا کامپایل
--   می‌کند، پس بدون این GO خطای «Msg 1911: Column name 'RoleId' does not
--   exist» می‌گیریم و کل راه‌اندازی دیتابیس (EnsureSchema) شکست می‌خورد.

IF COL_LENGTH(N'central.News', N'UpdatedBy') IS NULL
    ALTER TABLE [central].[News] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'central.BlogPosts', N'UpdatedBy') IS NULL
    ALTER TABLE [central].[BlogPosts] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'central.GalleryItems', N'UpdatedAt') IS NULL
    ALTER TABLE [central].[GalleryItems] ADD UpdatedAt DATETIME2 NULL;

IF COL_LENGTH(N'central.GalleryItems', N'UpdatedBy') IS NULL
    ALTER TABLE [central].[GalleryItems] ADD UpdatedBy NVARCHAR(100) NULL;

-- FK Users.RoleId → Roles (فقط اگر هنوز وجود ندارد).
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_Users_Roles' AND parent_object_id = OBJECT_ID(N'central.Users'))
   AND COL_LENGTH(N'central.Users', N'RoleId') IS NOT NULL
BEGIN
    -- کاربران قدیمی ممکن است RoleId نامعتبر (نقش حذف‌شده) داشته باشند؛
    -- قبل از افزودن FK آن‌ها را پاک می‌کنیم وگرنه ALTER با Msg 547 می‌شکند.
    UPDATE u SET u.RoleId = NULL
    FROM [central].[Users] u
    WHERE u.RoleId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [central].[Roles] r WHERE r.RoleId = u.RoleId);

    ALTER TABLE [central].[Users]
        ADD CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES [central].[Roles](RoleId);
END
GO

-- child/junction timestamp completeness (idempotent)
IF COL_LENGTH(N'central.RolePermissions', N'CreatedAt') IS NULL
    ALTER TABLE [central].[RolePermissions] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_RolePermissions_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'central.RolePermissions', N'UpdatedAt') IS NULL
    ALTER TABLE [central].[RolePermissions] ADD UpdatedAt DATETIME2 NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company & Multi-Fiscal-Year
-- ─────────────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Companies')
BEGIN
    CREATE TABLE [central].[Companies] (
        CompanyId         INT IDENTITY(1,1) PRIMARY KEY,
        CompanyName       NVARCHAR(200) NOT NULL,
        IsActive          BIT NOT NULL DEFAULT 1,
        IsDeleted         BIT NOT NULL DEFAULT 0,
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'FiscalYears')
BEGIN
    CREATE TABLE [central].[FiscalYears] (
        FiscalYearId      INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId         INT NOT NULL,
        YearName          NVARCHAR(50) NOT NULL,
        StartDate         DATE NOT NULL,
        EndDate           DATE NOT NULL,
        IsActive          BIT NOT NULL DEFAULT 1,
        IsDeleted         BIT NOT NULL DEFAULT 0,
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        CONSTRAINT FK_FiscalYears_Companies FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'UserCompanies')
BEGIN
    CREATE TABLE [central].[UserCompanies] (
        UserId            INT NOT NULL,
        CompanyId         INT NOT NULL,
        CONSTRAINT PK_UserCompanies PRIMARY KEY (UserId, CompanyId),
        CONSTRAINT FK_UserCompanies_Users FOREIGN KEY (UserId) REFERENCES [central].[Users](UserId),
        CONSTRAINT FK_UserCompanies_Companies FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'UserFiscalYears')
BEGIN
    CREATE TABLE [central].[UserFiscalYears] (
        UserId            INT NOT NULL,
        FiscalYearId      INT NOT NULL,
        CONSTRAINT PK_UserFiscalYears PRIMARY KEY (UserId, FiscalYearId),
        CONSTRAINT FK_UserFiscalYears_Users FOREIGN KEY (UserId) REFERENCES [central].[Users](UserId),
        CONSTRAINT FK_UserFiscalYears_FiscalYears FOREIGN KEY (FiscalYearId) REFERENCES [central].[FiscalYears](FiscalYearId)
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'UserActiveContext')
BEGIN
    CREATE TABLE [central].[UserActiveContext] (
        UserId            INT NOT NULL PRIMARY KEY,
        ActiveCompanyId   INT NULL,
        ActiveFiscalYearId INT NULL,
        CONSTRAINT FK_UserActiveContext_Users FOREIGN KEY (UserId) REFERENCES [central].[Users](UserId),
        CONSTRAINT FK_UserActiveContext_Companies FOREIGN KEY (ActiveCompanyId) REFERENCES [central].[Companies](CompanyId),
        CONSTRAINT FK_UserActiveContext_FiscalYears FOREIGN KEY (ActiveFiscalYearId) REFERENCES [central].[FiscalYears](FiscalYearId)
    );
END
GO
