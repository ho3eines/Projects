-- =============================================
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
