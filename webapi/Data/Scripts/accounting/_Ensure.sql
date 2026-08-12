-- =============================================
-- webapi/Data/Scripts/accounting/_Ensure.sql
-- Schema: accounting
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'accounting')
    EXEC(N'CREATE SCHEMA [accounting]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'accounting' AND t.name = N'Documents')
BEGIN
    CREATE TABLE [accounting].[Documents] (
        DocumentId        INT IDENTITY(1,1) PRIMARY KEY,
        DocumentNumber    NVARCHAR(50) NOT NULL,
        DocumentDate      DATE NOT NULL,
        DocumentType      NVARCHAR(50) NULL,
        CounterPartyName  NVARCHAR(200) NULL,
        TotalAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyCode      NVARCHAR(10) NULL,
        Status            NVARCHAR(50) NOT NULL DEFAULT N'Draft',
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        IsDeleted         BIT NOT NULL DEFAULT 0
    );
END
