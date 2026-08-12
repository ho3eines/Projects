-- =============================================
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
