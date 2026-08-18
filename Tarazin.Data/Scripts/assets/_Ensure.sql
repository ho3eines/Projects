-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/assets/_Ensure.sql
-- Schema: assets (اموال و دارایی ثابت)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'assets')
    EXEC(N'CREATE SCHEMA [assets]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'assets' AND t.name = N'FixedAssets')
BEGIN
    CREATE TABLE [assets].[FixedAssets] (
        AssetId          INT IDENTITY(1,1) PRIMARY KEY,
        AssetCode        NVARCHAR(50) NOT NULL UNIQUE,
        Title            NVARCHAR(200) NOT NULL,
        Category         NVARCHAR(80) NULL,             -- ماشین‌آلات | تجهیزات | ساختمان | خودرو | …
        PurchaseDate     DATE NOT NULL,
        PurchaseCost     DECIMAL(18,2) NOT NULL DEFAULT 0,
        UsefulLifeMonths INT NOT NULL DEFAULT 60,
        ResidualValue    DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status           NVARCHAR(30) NOT NULL DEFAULT N'Active',  -- Active | Scrapped | Transferred
        IsActive         BIT NOT NULL DEFAULT 1,
        IsDeleted        BIT NOT NULL DEFAULT 0,
        CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt        DATETIME2 NULL,
        CreatedBy        NVARCHAR(100) NULL,
        UpdatedBy        NVARCHAR(100) NULL
    );
END

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: FixedAssets per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'assets.FixedAssets', N'CompanyId') IS NULL
    ALTER TABLE [assets].[FixedAssets] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_FixedAssets_Company')
    ALTER TABLE [assets].[FixedAssets] WITH CHECK ADD CONSTRAINT FK_FixedAssets_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [assets].[FixedAssets] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_FixedAssets INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_FixedAssets IS NOT NULL
        UPDATE [assets].[FixedAssets] SET CompanyId = @DefaultCompanyId_FixedAssets WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FixedAssets_Company' AND object_id = OBJECT_ID(N'[assets].[FixedAssets]'))
    CREATE INDEX IX_FixedAssets_Company ON [assets].[FixedAssets](CompanyId) WHERE CompanyId IS NOT NULL;
GO
