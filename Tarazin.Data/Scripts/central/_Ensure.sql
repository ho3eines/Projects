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
        CompanyId   INT NULL,
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
IF COL_LENGTH(N'central.AuditLog', N'CompanyId') IS NULL
    ALTER TABLE [central].[AuditLog] ADD CompanyId INT NULL;

-- Contract: Party (Core owner) — v2 adds NationalId.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'Parties')
BEGIN
    CREATE TABLE [central].[Parties] (
        PartyId     INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId   INT NULL,
        PartyCode   NVARCHAR(50) NOT NULL,
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
        UpdatedBy   NVARCHAR(100) NULL,
        CONSTRAINT UQ_Parties_Company_Code UNIQUE (CompanyId, PartyCode)
    );
    CREATE INDEX IX_Parties_Type ON [central].[Parties](PartyType, IsDeleted);
END
IF COL_LENGTH(N'central.Parties', N'CompanyId') IS NULL
    ALTER TABLE [central].[Parties] ADD CompanyId INT NULL;

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

-- ─────────────────────────────────────────────────────────────
-- FiscalYear lifecycle: وضعیت سال مالی (Open / Closed) و یکتایی شرکت+سال
-- ─────────────────────────────────────────────────────────────
--
-- ستون IsActive قدیمی برای «فعال/غیرفعال» نگه داشته می‌شود تا گزارش‌های
-- موجود نشکنند. ستون جدید Status چرخهٔ حیات سال مالی را مدل می‌کند:
--   Open   = سال باز است و ثبت سند عادی مجاز است.
--   Closed = سال بسته شده و هیچ تغییر حسابداری (از طریق منطق عادی) پذیرفته نیست.
IF COL_LENGTH(N'central.FiscalYears', N'Status') IS NULL
    ALTER TABLE [central].[FiscalYears] ADD [Status] NVARCHAR(20) NOT NULL
        CONSTRAINT DF_FiscalYears_Status DEFAULT N'Open';
GO

-- یکتایی (شرکت، نام سال) جلوی ایجاد سال مالی تکراری را حتی در شرایط
-- هم‌زمان (Race Condition) در سطح دیتابیس می‌گیرد.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_FiscalYears_Company_Year' AND object_id = OBJECT_ID(N'central.FiscalYears'))
    CREATE UNIQUE INDEX UX_FiscalYears_Company_Year
        ON [central].[FiscalYears](CompanyId, YearName)
        WHERE IsDeleted = 0;
GO

-- وضعیت سال‌های از قبل موجود (مقدار قدیمی NULL با مقدار پیش‌فرض پر شده،
-- اما برای اطمینان در دیتابیس‌های ارتقا یافته صریحاً تنظیم می‌شود).
UPDATE [central].[FiscalYears]
SET [Status] = N'Open'
WHERE [Status] IS NULL OR LTRIM(RTRIM([Status])) = N'';
GO

-- ─────────────────────────────────────────────────────────────
-- Party tenant backfill (customer and supplier master)
IF COL_LENGTH(N'central.Parties', N'CompanyId') IS NOT NULL
BEGIN
    DECLARE @PartyDefaultCompanyId INT=(SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted=0 ORDER BY CompanyId);
    IF @PartyDefaultCompanyId IS NOT NULL UPDATE [central].[Parties] SET CompanyId=@PartyDefaultCompanyId WHERE CompanyId IS NULL;
END
GO

-- MAUI credential broker control plane (server-side only)
-- ─────────────────────────────────────────────────────────────
-- This dedicated registry is an explicit deployment/customer boundary. It
-- deliberately does not reuse commerce customers from [store].[Customers].
-- Rows are provisioned server-side; no random/default customer is enabled.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'CredentialCustomers')
BEGIN
    CREATE TABLE [central].[CredentialCustomers] (
        CredentialCustomerId    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CustomerGuid            UNIQUEIDENTIFIER NOT NULL,
        CompanyId               INT NOT NULL,
        DisplayName             NVARCHAR(200) NOT NULL,
        IsActive                BIT NOT NULL DEFAULT 1,
        CredentialAccessEnabled BIT NOT NULL DEFAULT 0,
        CreatedAt               DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt               DATETIME2 NULL,
        CONSTRAINT UQ_CredentialCustomers_CustomerGuid UNIQUE (CustomerGuid),
        CONSTRAINT UQ_CredentialCustomers_Company UNIQUE (CompanyId),
        CONSTRAINT FK_CredentialCustomers_Company FOREIGN KEY (CompanyId)
            REFERENCES [central].[Companies](CompanyId)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'MobileCredentialSessions')
BEGIN
    CREATE TABLE [central].[MobileCredentialSessions] (
        SessionId              UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        SessionFamilyId        UNIQUEIDENTIFIER NOT NULL,
        TokenHash              CHAR(64) NOT NULL,
        CustomerGuid           UNIQUEIDENTIFIER NOT NULL,
        CustomerId             INT NOT NULL,
        CompanyId              INT NOT NULL,
        UserId                 INT NOT NULL,
        SqlLoginName            SYSNAME NOT NULL,
        CredentialExpiresAt    DATETIME2 NOT NULL,
        SessionExpiresAt       DATETIME2 NOT NULL,
        CreatedAt              DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ActivatedAt            DATETIME2 NULL,
        LastRefreshedAt        DATETIME2 NULL,
        RevokedAt              DATETIME2 NULL,
        CONSTRAINT UQ_MobileCredentialSessions_TokenHash UNIQUE (TokenHash),
        CONSTRAINT UQ_MobileCredentialSessions_Login UNIQUE (SqlLoginName),
        CONSTRAINT FK_MobileCredentialSessions_Customer FOREIGN KEY (CustomerId)
            REFERENCES [central].[CredentialCustomers](CredentialCustomerId),
        CONSTRAINT FK_MobileCredentialSessions_User FOREIGN KEY (UserId) REFERENCES [central].[Users](UserId),
        CONSTRAINT FK_MobileCredentialSessions_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_MobileCredentialSessions_Expiry
        ON [central].[MobileCredentialSessions](CredentialExpiresAt, SessionExpiresAt, RevokedAt);
    CREATE INDEX IX_MobileCredentialSessions_Family
        ON [central].[MobileCredentialSessions](SessionFamilyId, RevokedAt);
END
GO

-- Upgrade pre-family broker rows without invalidating a live deployment. A
-- pre-existing row was already active if it survived issuance, so CreatedAt is
-- the safest activation backfill. New issuance is inserted pending and is
-- activated only after its SQL principal exists.
IF COL_LENGTH(N'central.MobileCredentialSessions', N'SessionFamilyId') IS NULL
    ALTER TABLE [central].[MobileCredentialSessions]
        ADD SessionFamilyId UNIQUEIDENTIFIER NULL;
GO
UPDATE [central].[MobileCredentialSessions]
SET SessionFamilyId = SessionId
WHERE SessionFamilyId IS NULL;
GO
ALTER TABLE [central].[MobileCredentialSessions]
    ALTER COLUMN SessionFamilyId UNIQUEIDENTIFIER NOT NULL;
GO
IF COL_LENGTH(N'central.MobileCredentialSessions', N'ActivatedAt') IS NULL
BEGIN
    -- This backfill belongs only to the column-add migration. Rows written by
    -- pre-activation broker versions were live once persisted; after the column
    -- exists, a NULL value means deliberately pending and must never be revived
    -- by a later idempotent startup.
    EXEC(N'ALTER TABLE [central].[MobileCredentialSessions]
              ADD ActivatedAt DATETIME2 NULL;');
    EXEC(N'UPDATE [central].[MobileCredentialSessions]
           SET ActivatedAt = CreatedAt
           WHERE ActivatedAt IS NULL AND RevokedAt IS NULL;');
END
GO
IF NOT EXISTS
   (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[central].[MobileCredentialSessions]')
      AND name = N'IX_MobileCredentialSessions_Family')
    CREATE INDEX IX_MobileCredentialSessions_Family
        ON [central].[MobileCredentialSessions](SessionFamilyId, RevokedAt);
GO

-- Authoritative v4 tenant-default function. Generated mobile principals can
-- resolve only their live broker-bound company. Trusted Web/bootstrap identities
-- retain the existing active-context/fallback behavior used by business-table
-- defaults. The object version makes upgrades explicit and avoids ALTERing a
-- schema-bound function on every startup.
DECLARE @MobileCompanyFunctionVersion INT =
(
    SELECT TRY_CONVERT(INT, ep.[value])
    FROM sys.extended_properties AS ep
    WHERE ep.class = 1
      AND ep.major_id = OBJECT_ID(N'[central].[fn_MobileCompanyId]')
      AND ep.minor_id = 0
      AND ep.name = N'Tarazin.SecurityDefinitionVersion'
);

IF OBJECT_ID(N'[central].[fn_MobileCompanyId]', N'FN') IS NULL
   OR COALESCE(@MobileCompanyFunctionVersion, 0) < 4
BEGIN
    DECLARE @MobileCompanyFunctionSql NVARCHAR(MAX) =
        CASE WHEN OBJECT_ID(N'[central].[fn_MobileCompanyId]', N'FN') IS NULL
             THEN N'CREATE' ELSE N'ALTER' END + N'
        FUNCTION [central].[fn_MobileCompanyId]()
        RETURNS INT
        WITH SCHEMABINDING
        AS
        BEGIN
            DECLARE @CompanyId INT;
            IF LEFT(USER_NAME(), 5) = N''tz_m_''
                SELECT @CompanyId = s.CompanyId
                FROM [central].[MobileCredentialSessions] AS s
                JOIN [central].[CredentialCustomers] AS cc
                  ON cc.CredentialCustomerId = s.CustomerId
                 AND cc.CustomerGuid = s.CustomerGuid
                 AND cc.CompanyId = s.CompanyId
                JOIN [central].[Companies] AS c ON c.CompanyId = s.CompanyId
                WHERE s.SqlLoginName = USER_NAME()
                  AND s.ActivatedAt IS NOT NULL
                  AND s.RevokedAt IS NULL
                  AND s.CredentialExpiresAt > SYSUTCDATETIME()
                  AND s.SessionExpiresAt > SYSUTCDATETIME()
                  AND cc.IsActive = 1
                  AND cc.CredentialAccessEnabled = 1
                  AND c.IsActive = 1
                  AND c.IsDeleted = 0;
            ELSE
            BEGIN
                SET @CompanyId = TRY_CONVERT(INT, SESSION_CONTEXT(N''TarazinCompanyId''));
                IF @CompanyId IS NULL
                    SELECT TOP (1) @CompanyId = c.CompanyId
                    FROM [central].[Companies] AS c
                    WHERE c.IsDeleted = 0
                    ORDER BY c.CompanyId;
            END;
            RETURN @CompanyId;
        END';
    EXEC sys.sp_executesql @MobileCompanyFunctionSql;

    IF EXISTS
       (SELECT 1 FROM sys.extended_properties
        WHERE class = 1 AND major_id = OBJECT_ID(N'[central].[fn_MobileCompanyId]')
          AND minor_id = 0 AND name = N'Tarazin.SecurityDefinitionVersion')
        EXEC sys.sp_updateextendedproperty
            @name = N'Tarazin.SecurityDefinitionVersion', @value = 4,
            @level0type = N'SCHEMA', @level0name = N'central',
            @level1type = N'FUNCTION', @level1name = N'fn_MobileCompanyId';
    ELSE
        EXEC sys.sp_addextendedproperty
            @name = N'Tarazin.SecurityDefinitionVersion', @value = 4,
            @level0type = N'SCHEMA', @level0name = N'central',
            @level1type = N'FUNCTION', @level1name = N'fn_MobileCompanyId';
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'central' AND t.name = N'CredentialRequestNonces')
BEGIN
    CREATE TABLE [central].[CredentialRequestNonces] (
        NonceHash   CHAR(64) NOT NULL PRIMARY KEY,
        ExpiresAt   DATETIME2 NOT NULL,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_CredentialRequestNonces_Expiry
        ON [central].[CredentialRequestNonces](ExpiresAt);
END
GO
