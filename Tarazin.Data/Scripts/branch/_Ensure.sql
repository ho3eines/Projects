-- =============================================
-- Cross-schema: central
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

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Branches per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'branch.Branches', N'CompanyId') IS NULL
    ALTER TABLE [branch].[Branches] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Branches_Company')
    ALTER TABLE [branch].[Branches] WITH CHECK ADD CONSTRAINT FK_Branches_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [branch].[Branches] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Branches INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Branches IS NOT NULL
        UPDATE [branch].[Branches] SET CompanyId = @DefaultCompanyId_Branches WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Branches_Company' AND object_id = OBJECT_ID(N'[branch].[Branches]'))
    CREATE INDEX IX_Branches_Company ON [branch].[Branches](CompanyId) WHERE CompanyId IS NOT NULL;
GO
