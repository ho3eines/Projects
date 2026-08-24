-- =============================================
-- Tarazin.Data/Scripts/central/_MobileRlsSeed.sql
-- Schema: central
-- Purpose: DEV/TEST seed — reproduces the multi-company + orphan-row
--          scenario that triggers _MobileSecurity's 51091 guard, so the
--          guard behavior and the backfill fix can be verified.
--
-- Run order (from repo root, against TarazinMaster):
--   1) sqlcmd -i Tarazin.Data/Scripts/central/_MobileRlsSeed.sql
--        → inserts one business row with CompanyId = NULL (marked
--          CreatedBy = N'rlstest') + prints pre-state.
--   2) sqlcmd -i Tarazin.Data/Scripts/central/_MobileSecurity.sql
--        → EXPECTED: THROW 51091 — proves the guard still protects real
--          tenant data (only central.AuditLog is exempt).
--   3) sqlcmd -i Tarazin.Data/Scripts/central/_MobileBackfill.sql
--        → adds missing CompanyId columns + backfills every orphan row.
--   4) sqlcmd -i Tarazin.Data/Scripts/central/_MobileSecurity.sql
--        → EXPECTED: succeeds — RLS policies created; AuditLog NULL rows
--          (system-level by design) no longer block.
--   5) Verify + cleanup:
--        SELECT * FROM sys.security_policies WHERE name LIKE N'Mobile%';
--        DELETE FROM [treasury].[Banks] WHERE BankCode = N'RLS-999';
--
-- Idempotent: safe to re-run.
-- =============================================
SET NOCOUNT ON;
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF; tables with filtered indexes
-- (or RLS policies) reject inserts in that mode.
SET QUOTED_IDENTIFIER ON;

-- 1) Ensure a multi-company state exists (the guard only fires when more
--    than one company is present).
IF (SELECT COUNT(*) FROM [central].[Companies] WHERE IsDeleted = 0) < 2
BEGIN
    PRINT N'-- fewer than 2 companies; creating a second test company';
    INSERT INTO [central].[Companies] (CompanyName, IsActive, CreatedBy)
    VALUES (N'شرکت تست RLS', 1, N'rlstest');
END

-- 2) Insert a genuine business row with NO CompanyId — the exact condition
--    the 51091 guard exists to catch. Marked with a unique BankCode so it
--    can be cleaned up.
IF NOT EXISTS (SELECT 1 FROM [treasury].[Banks] WHERE BankCode = N'RLS-999')
BEGIN
    PRINT N'-- seeding orphan row (CompanyId = NULL) in [treasury].[Banks]';
    INSERT INTO [treasury].[Banks] (BankCode, Title, IsActive)
    VALUES (N'RLS-999', N'بانک تست RLS', 1);
END

-- 3) Print the pre-backfill state so the scenario is visible.
PRINT N'--- pre-state ------------------------------------------------------';
DECLARE @OrphanBanks INT = (SELECT COUNT(*) FROM [treasury].[Banks] WHERE CompanyId IS NULL);
DECLARE @AuditNulls INT = (SELECT COUNT(*) FROM [central].[AuditLog] WHERE CompanyId IS NULL);
DECLARE @Companies INT = (SELECT COUNT(*) FROM [central].[Companies] WHERE IsDeleted = 0);
PRINT N'active companies        = ' + CAST(@Companies AS NVARCHAR(10));
PRINT N'treasury.Banks NULL    = ' + CAST(@OrphanBanks AS NVARCHAR(10)) + N' (seeded test row)';
PRINT N'central.AuditLog NULL  = ' + CAST(@AuditNulls AS NVARCHAR(10)) + N' (system-level, must stay NULL)';
PRINT N'';
PRINT N'--- next: run _MobileSecurity (expect 51091), then _MobileBackfill,';
PRINT N'        then _MobileSecurity again (expect success) ----------------';
