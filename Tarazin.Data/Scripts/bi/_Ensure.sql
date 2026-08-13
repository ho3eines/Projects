-- =============================================
-- Tarazin.Data/Scripts/bi/_Ensure.sql
-- Schema: bi (داشبورد و Business Intelligence)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'bi')
    EXEC(N'CREATE SCHEMA [bi]');

-- اهداف (Target vs Actual — PRD BI §117): تعریف هدف برای فروش/سود/هزینه/وصول.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'bi' AND t.name = N'Targets')
BEGIN
    CREATE TABLE [bi].[Targets] (
        TargetId     INT IDENTITY(1,1) PRIMARY KEY,
        TargetKey    NVARCHAR(30) NOT NULL,             -- Sales | Profit | Expense | Collection
        Title        NVARCHAR(120) NOT NULL,
        Period       NVARCHAR(10) NOT NULL DEFAULT N'Month',  -- Month | Year
        PeriodYear   INT NOT NULL,
        PeriodMonth  INT NULL,
        TargetAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL,
        CreatedBy    NVARCHAR(100) NULL,
        CONSTRAINT UX_Targets UNIQUE (TargetKey, Period, PeriodYear, PeriodMonth)
    );
END
