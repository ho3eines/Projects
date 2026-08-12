-- =============================================
-- webapi/Data/Scripts/central/_Ensure.sql
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
