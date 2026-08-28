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
        CONSTRAINT FK_RunItems_Runs FOREIGN KEY (RunId) REFERENCES [payroll].[PayrollRuns](RunId),
        CompanyId    INT NULL
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
-- Migrations: Outbox — ستون‌های اجاره/آخرین تلاش (برای دیسپچر پس‌زمینه)
-- =============================================
-- ClaimedAt: زمان برداشتن ردیف توسط یک worker؛ با انقضای Lease دوباره قابل برداشتن است.
-- LastAttemptAt: آخرین زمان تلاش برای ثبت (دیباگ/مانیتورینگ).
IF COL_LENGTH(N'payroll.Outbox', N'ClaimedAt') IS NULL
    ALTER TABLE [payroll].[Outbox] ADD ClaimedAt DATETIME2 NULL;
IF COL_LENGTH(N'payroll.Outbox', N'LastAttemptAt') IS NULL
    ALTER TABLE [payroll].[Outbox] ADD LastAttemptAt DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Outbox_Ready' AND object_id = OBJECT_ID(N'[payroll].[Outbox]'))
    CREATE INDEX IX_Outbox_Ready ON [payroll].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
GO

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

-- ═════════════════════════════════════════════════════════════════
-- EmploymentOrders: حکم اداری (قرارداد کارمند)
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'EmploymentOrders')
BEGIN
    CREATE TABLE [payroll].[EmploymentOrders] (
        OrderId       INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId    INT NOT NULL,
        ContractType  NVARCHAR(30) NOT NULL DEFAULT N'Permanent', -- Permanent | Fixed | PartTime | Intern
        StartDate     DATE NULL,
        EndDate       DATE NULL,
        BaseSalary    DECIMAL(18,2) NOT NULL DEFAULT 0,
        HousingAllowance DECIMAL(18,2) NOT NULL DEFAULT 0,
        FoodAllowance    DECIMAL(18,2) NOT NULL DEFAULT 0,
        TransportAllowance DECIMAL(18,2) NOT NULL DEFAULT 0,
        InsurancePct  DECIMAL(5,2) NOT NULL DEFAULT 7.00,  -- سهم کارمند بیمه
        TaxExemptCount INT NOT NULL DEFAULT 0, -- معافیت مالیاتی (تعداد تحت تکفل رسمی)
        IsActive      BIT NOT NULL DEFAULT 1,
        Notes         NVARCHAR(500) NULL,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2 NULL,
        CreatedBy     NVARCHAR(100) NULL,
        UpdatedBy     NVARCHAR(100) NULL,
        CompanyId     INT NULL,
        CONSTRAINT FK_EmploymentOrders_Employees FOREIGN KEY (EmployeeId) REFERENCES [payroll].[Employees](EmployeeId),
        CONSTRAINT FK_EmploymentOrders_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_EmploymentOrders_Employee ON [payroll].[EmploymentOrders](EmployeeId);
    CREATE INDEX IX_EmploymentOrders_Company ON [payroll].[EmploymentOrders](CompanyId) WHERE CompanyId IS NOT NULL;
END

-- ═════════════════════════════════════════════════════════════════
-- SalaryTemplates: الگوی اقلام حقوق (اضافات و کسورات از پیش تعریف‌شده)
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'SalaryTemplates')
BEGIN
    CREATE TABLE [payroll].[SalaryTemplates] (
        TemplateId  INT IDENTITY(1,1) PRIMARY KEY,
        Title       NVARCHAR(120) NOT NULL,
        Category    NVARCHAR(30) NOT NULL DEFAULT N'Earning', -- Earning | Deduction
        IsPercent   BIT NOT NULL DEFAULT 0,      -- آیا درصد از پایه است؟
        Percentage  DECIMAL(5,2) NULL,            -- مقدار درصد (مثلاً 7.00 = 7%)
        FixedAmount DECIMAL(18,2) NULL,          -- مبلغ ثابت
        SortOrder   INT NOT NULL DEFAULT 0,
        IsActive    BIT NOT NULL DEFAULT 1,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2 NULL,
        CreatedBy   NVARCHAR(100) NULL,
        UpdatedBy   NVARCHAR(100) NULL,
        CompanyId   INT NULL,
        CONSTRAINT FK_SalaryTemplates_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_SalaryTemplates_Company ON [payroll].[SalaryTemplates](CompanyId) WHERE CompanyId IS NOT NULL;
END

-- ═════════════════════════════════════════════════════════════════
-- PayrollRuns: مایگریشن — اضافه‌شدن وضعیت‌های جدید
-- ═════════════════════════════════════════════════════════════════
-- Draft = دوره باز (قابل ویرایش اقلام)
-- Finalized = نهایی‌شده (اقلام قفل، قابل پرداخت)
-- Closed = بسته‌شده (غیرقابل برگشت)
-- Reopened = بازگشایی‌شده (برگشت از Finalized)
IF COL_LENGTH(N'payroll.PayrollRuns', N'LockedAt') IS NULL
    ALTER TABLE [payroll].[PayrollRuns] ADD LockedAt DATETIME2 NULL;
IF COL_LENGTH(N'payroll.PayrollRuns', N'LockedBy') IS NULL
    ALTER TABLE [payroll].[PayrollRuns] ADD LockedBy NVARCHAR(100) NULL;
GO

-- ═════════════════════════════════════════════════════════════════
-- AttendanceLogs: حضورغیاب روزانه (ورود/خروج/اضافه‌کار)
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'AttendanceLogs')
BEGIN
    CREATE TABLE [payroll].[AttendanceLogs] (
        AttendanceId   INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId     INT NOT NULL,
        CompanyId      INT NOT NULL,
        AttendanceDate DATE NOT NULL,
        CheckIn        TIME NULL,
        CheckOut       TIME NULL,
        WorkMinutes    INT NOT NULL DEFAULT 0,       -- دقیقه کارکرد محاسبه‌شده
        OvertimeMinutes INT NOT NULL DEFAULT 0,      -- دقیقه اضافه‌کار (بالای ساعت استاندارد)
        Notes          NVARCHAR(300) NULL,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CreatedBy      NVARCHAR(100) NULL,
        UpdatedBy      NVARCHAR(100) NULL,
        CONSTRAINT FK_Attendance_Employees FOREIGN KEY (EmployeeId) REFERENCES [payroll].[Employees](EmployeeId),
        CONSTRAINT FK_Attendance_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE UNIQUE INDEX UX_Attendance_Employee_Date ON [payroll].[AttendanceLogs](EmployeeId, AttendanceDate);
    CREATE INDEX IX_Attendance_Company_Date ON [payroll].[AttendanceLogs](CompanyId, AttendanceDate);
END

-- ═════════════════════════════════════════════════════════════════
-- LeaveRecords: مرخصی (استحقاقی/بدون حقوق)
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'LeaveRecords')
BEGIN
    CREATE TABLE [payroll].[LeaveRecords] (
        LeaveId        INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId     INT NOT NULL,
        CompanyId      INT NOT NULL,
        StartDate      DATE NOT NULL,
        EndDate        DATE NOT NULL,
        Days           DECIMAL(6,2) NOT NULL DEFAULT 1,   -- روزهای مرخصی
        LeaveType      NVARCHAR(30) NOT NULL DEFAULT N'Annual', -- Annual | Sick | Unpaid | Hourly
        IsPaid         BIT NOT NULL DEFAULT 1,            -- استحقاقی (با حقوق) یا بدون حقوق
        Description    NVARCHAR(300) NULL,
        ApprovedBy     NVARCHAR(100) NULL,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CreatedBy      NVARCHAR(100) NULL,
        UpdatedBy      NVARCHAR(100) NULL,
        CONSTRAINT FK_Leave_Employees FOREIGN KEY (EmployeeId) REFERENCES [payroll].[Employees](EmployeeId),
        CONSTRAINT FK_Leave_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    CREATE INDEX IX_Leave_Employee_Start ON [payroll].[LeaveRecords](EmployeeId, StartDate);
    CREATE INDEX IX_Leave_Company_Start ON [payroll].[LeaveRecords](CompanyId, StartDate);
END

-- ═════════════════════════════════════════════════════════════════
-- PayrollSettings: تنظیمات اتصال به حسابداری/خزانه
-- ═════════════════════════════════════════════════════════════════
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'payroll' AND t.name = N'PayrollSettings')
BEGIN
    CREATE TABLE [payroll].[PayrollSettings] (
        SettingId         INT IDENTITY(1,1) PRIMARY KEY,
        PayableAccountCode NVARCHAR(20) NULL,  -- کد حساب تفصیلی «حقوق پرداختی»
        InsuranceAccountCode NVARCHAR(20) NULL, -- کد حساب تفصیلی «بیمه پرداختی»
        TaxAccountCode    NVARCHAR(20) NULL,   -- کد حساب تفصیلی «مالیات پرداختی»
        BankAccountCode   NVARCHAR(20) NULL,   -- کد حساب بانکی پرداخت حقوق
        DocumentPrefix    NVARCHAR(20) NULL,   -- پیشوند شماره سند حسابداری (مثلاً HR)
        UpdatedAt         DATETIME2 NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        CompanyId         INT NULL,
        CONSTRAINT FK_PayrollSettings_Company FOREIGN KEY (CompanyId) REFERENCES [central].[Companies](CompanyId)
    );
    -- فقط یک ردیف تنظیمات برای هر شرکت
    CREATE UNIQUE INDEX IX_PayrollSettings_Company ON [payroll].[PayrollSettings](CompanyId) WHERE CompanyId IS NOT NULL;
END
