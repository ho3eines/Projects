-- =============================================
-- Tarazin.Data/Scripts/branch/_Ensure.sql
-- Schema: branch (شعب)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'branch')
    EXEC(N'CREATE SCHEMA [branch]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'branch' AND t.name = N'Branches')
BEGIN
    CREATE TABLE [branch].[Branches] (
        BranchId   INT IDENTITY(1,1) PRIMARY KEY,
        BranchCode NVARCHAR(30) NOT NULL UNIQUE,
        Title      NVARCHAR(200) NOT NULL,
        Location   NVARCHAR(200) NULL,
        Manager    NVARCHAR(100) NULL,
        IsActive   BIT NOT NULL DEFAULT 1,
        IsDeleted  BIT NOT NULL DEFAULT 0,
        CreatedAt  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt  DATETIME2 NULL,
        CreatedBy  NVARCHAR(100) NULL,
        UpdatedBy  NVARCHAR(100) NULL
    );
END
