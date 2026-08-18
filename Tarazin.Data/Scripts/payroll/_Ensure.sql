-- =============================================
-- Cross-schema: central
-- Tarazin.Data/Scripts/payroll/_Ensure.sql
-- Schema: payroll (حقوق و دستمزد)
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'payroll')
    EXEC(N'CREATE SCHEMA [payroll]');

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'Employees')
BEGIN
    CREATE TABLE [payroll].[Employees] (
        EmployeeId   INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeCode NVARCHAR(30) NOT NULL UNIQUE,
        FullName     NVARCHAR(200) NOT NULL,
        NationalId   NVARCHAR(20) NULL,
        Department   NVARCHAR(80) NULL,
        BaseSalary   DECIMAL(18,2) NOT NULL DEFAULT 0,
        IsActive     BIT NOT NULL DEFAULT 1,
        IsDeleted    BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2 NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'SalaryItems')
BEGIN
    CREATE TABLE [payroll].[SalaryItems] (
        SalaryItemId INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId   INT NOT NULL,
        Period       NVARCHAR(20) NOT NULL,             -- e.g. 1405-05
        Title        NVARCHAR(120) NOT NULL,            -- حقوق پایه / حق مسکن / بیمه / مالیات ...
        Amount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        IsDeduction  BIT NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_SalaryItems_Employees FOREIGN KEY (EmployeeId) REFERENCES [payroll].[Employees](EmployeeId)
    );
    CREATE INDEX IX_SalaryItems_Period ON [payroll].[SalaryItems](Period, EmployeeId);
END

-- Contract: PayrollRun (owner: payroll).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'PayrollRuns')
BEGIN
    CREATE TABLE [payroll].[PayrollRuns] (
        RunId         INT IDENTITY(1,1) PRIMARY KEY,
        Period        NVARCHAR(20) NOT NULL UNIQUE,
        EmployeeCount INT NOT NULL DEFAULT 0,
        NetTotal      DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status        NVARCHAR(30) NOT NULL DEFAULT N'Finalized',   -- Draft | Finalized | Posted
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(100) NULL
    );
END

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'PayrollRunItems')
BEGIN
    CREATE TABLE [payroll].[PayrollRunItems] (
        RunItemId    INT IDENTITY(1,1) PRIMARY KEY,
        RunId        INT NOT NULL,
        EmployeeId   INT NOT NULL,
        EmployeeName NVARCHAR(200) NOT NULL,
        Amount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_RunItems_Runs FOREIGN KEY (RunId) REFERENCES [payroll].[PayrollRuns](RunId)
    );
END

-- Event backbone (ADR-002).
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'Outbox')
BEGIN
    CREATE TABLE [payroll].[Outbox] (
        OutboxId       BIGINT IDENTITY(1,1) PRIMARY KEY,
        EventType      NVARCHAR(100) NOT NULL,
        EventKey       NVARCHAR(200) NOT NULL,
        Payload        NVARCHAR(MAX) NOT NULL,
        PayloadVersion INT NOT NULL DEFAULT 1,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ProcessedAt    DATETIME2 NULL,
        Attempts       INT NOT NULL DEFAULT 0,
        LastError      NVARCHAR(MAX) NULL
    );
    CREATE INDEX IX_Outbox_Ready ON [payroll].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
END

-- =============================================
-- Migrations: تکمیل ستون‌های CreatedAt/UpdatedAt/CreatedBy/UpdatedBy
-- =============================================
IF COL_LENGTH(N'payroll.Employees', N'CreatedBy') IS NULL
    ALTER TABLE [payroll].[Employees] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'payroll.Employees', N'UpdatedBy') IS NULL
    ALTER TABLE [payroll].[Employees] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'payroll.SalaryItems', N'UpdatedAt') IS NULL
    ALTER TABLE [payroll].[SalaryItems] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'payroll.SalaryItems', N'CreatedBy') IS NULL
    ALTER TABLE [payroll].[SalaryItems] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'payroll.SalaryItems', N'UpdatedBy') IS NULL
    ALTER TABLE [payroll].[SalaryItems] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'payroll.PayrollRuns', N'UpdatedAt') IS NULL
    ALTER TABLE [payroll].[PayrollRuns] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'payroll.PayrollRuns', N'UpdatedBy') IS NULL
    ALTER TABLE [payroll].[PayrollRuns] ADD UpdatedBy NVARCHAR(100) NULL;

IF COL_LENGTH(N'payroll.PayrollRunItems', N'CreatedAt') IS NULL
    ALTER TABLE [payroll].[PayrollRunItems] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_PayrollRunItems_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'payroll.PayrollRunItems', N'UpdatedAt') IS NULL
    ALTER TABLE [payroll].[PayrollRunItems] ADD UpdatedAt DATETIME2 NULL;

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: Employees per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'payroll.Employees', N'CompanyId') IS NULL
    ALTER TABLE [payroll].[Employees] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Employees_Company')
    ALTER TABLE [payroll].[Employees] WITH CHECK ADD CONSTRAINT FK_Employees_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [payroll].[Employees] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_Employees INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_Employees IS NOT NULL
        UPDATE [payroll].[Employees] SET CompanyId = @DefaultCompanyId_Employees WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Employees_Company' AND object_id = OBJECT_ID(N'[payroll].[Employees]'))
    CREATE INDEX IX_Employees_Company ON [payroll].[Employees](CompanyId) WHERE CompanyId IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────
-- Multi-Company: PayrollRuns per-company scoping
-- ─────────────────────────────────────────────────────────────
IF COL_LENGTH(N'payroll.PayrollRuns', N'CompanyId') IS NULL
    ALTER TABLE [payroll].[PayrollRuns] ADD CompanyId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PayrollRuns_Company')
    ALTER TABLE [payroll].[PayrollRuns] WITH CHECK ADD CONSTRAINT FK_PayrollRuns_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId);
GO
-- Backfill existing rows to first company
IF EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE CompanyId IS NULL)
BEGIN
    DECLARE @DefaultCompanyId_PayrollRuns INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
    IF @DefaultCompanyId_PayrollRuns IS NOT NULL
        UPDATE [payroll].[PayrollRuns] SET CompanyId = @DefaultCompanyId_PayrollRuns WHERE CompanyId IS NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PayrollRuns_Company' AND object_id = OBJECT_ID(N'[payroll].[PayrollRuns]'))
    CREATE INDEX IX_PayrollRuns_Company ON [payroll].[PayrollRuns](CompanyId) WHERE CompanyId IS NOT NULL;
GO
