-- Explicit backfill for business tables that have existing rows without
-- CompanyId when multiple companies exist. Run before _MobileSecurity.
-- Cross-schema: accounting, currency, payroll, store
--
-- NOTE: executed through DbService.ExecuteAsync (single Dapper command),
-- so this file must NOT contain GO batches. Both ALTER TABLE ADD and the
-- UPDATE referencing the column are run through sp_executesql because SQL
-- Server compiles the batch before ALTER takes effect — and on a FRESH
-- database the CompanyId column does not exist yet at all (it is added by
-- _MobileSecurity later), so a plain UPDATE would fail at compile time
-- (SqlNumber 207) even inside an IF COL_LENGTH guard.
SET NOCOUNT ON;
-- Tables with filtered indexes (e.g. store.Outbox) reject DML when
-- QUOTED_IDENTIFIER is OFF (sqlcmd default); Dapper/Microsoft.Data.SqlClient
-- default it ON. Declare it explicitly so both paths behave identically.
SET QUOTED_IDENTIFIER ON;

DECLARE @DefaultCompanyId INT = (
    SELECT TOP (1) CompanyId
    FROM [central].[Companies]
    WHERE IsDeleted = 0
    ORDER BY CompanyId
);

IF @DefaultCompanyId IS NOT NULL
BEGIN
    -- Tables that already have the column: backfill NULL rows only.
    IF COL_LENGTH(N'accounting.DocumentLines', N'CompanyId') IS NOT NULL
        EXEC sys.sp_executesql
            N'UPDATE [accounting].[DocumentLines] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
            N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;

    IF COL_LENGTH(N'currency.Wallets', N'CompanyId') IS NOT NULL
        EXEC sys.sp_executesql
            N'UPDATE [currency].[Wallets] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
            N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;

    IF COL_LENGTH(N'payroll.SalaryItems', N'CompanyId') IS NOT NULL
        EXEC sys.sp_executesql
            N'UPDATE [payroll].[SalaryItems] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
            N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;

    -- Tables created before the CompanyId migration: add the column first,
    -- then backfill. Without this, _MobileSecurity's 51091 guard aborts when
    -- multiple companies exist and any row lacks explicit ownership.
    -- central.AuditLog is deliberately NOT backfilled: its NULL rows are
    -- system-level records (startup migrations/seed/access syncs) that have
    -- no tenant by design; _MobileSecurity exempts it from the guard.
    -- Convention: docs/adr/ADR-004-auditlog-null-company.md
    IF COL_LENGTH(N'currency.AssetHoldings', N'CompanyId') IS NULL
        EXEC sys.sp_executesql N'ALTER TABLE [currency].[AssetHoldings] ADD [CompanyId] INT NULL;';
    EXEC sys.sp_executesql
        N'UPDATE [currency].[AssetHoldings] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
        N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;

    IF COL_LENGTH(N'currency.AssetValuationHistory', N'CompanyId') IS NULL
        EXEC sys.sp_executesql N'ALTER TABLE [currency].[AssetValuationHistory] ADD [CompanyId] INT NULL;';
    EXEC sys.sp_executesql
        N'UPDATE [currency].[AssetValuationHistory] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
        N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;

    IF COL_LENGTH(N'payroll.PayrollRunItems', N'CompanyId') IS NULL
        EXEC sys.sp_executesql N'ALTER TABLE [payroll].[PayrollRunItems] ADD [CompanyId] INT NULL;';
    EXEC sys.sp_executesql
        N'UPDATE [payroll].[PayrollRunItems] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
        N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;

    IF COL_LENGTH(N'store.Outbox', N'CompanyId') IS NULL
        EXEC sys.sp_executesql N'ALTER TABLE [store].[Outbox] ADD [CompanyId] INT NULL;';
    EXEC sys.sp_executesql
        N'UPDATE [store].[Outbox] SET [CompanyId] = @DefaultCompanyId WHERE [CompanyId] IS NULL;',
        N'@DefaultCompanyId INT', @DefaultCompanyId = @DefaultCompanyId;
END
