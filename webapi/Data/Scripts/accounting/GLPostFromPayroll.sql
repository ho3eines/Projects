-- =============================================
-- webapi/Data/Scripts/accounting/GLPostFromPayroll.sql
-- Schema: accounting | Consumer of PayrollFinalized (payroll → accounting)
-- Execute. Idempotent on RunId (ADR-002 dual-write).
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[PayrollPostings] WHERE RunId = @RunId)
BEGIN
    INSERT INTO [accounting].[PayrollPostings] (RunId, Period, EmployeeCount, NetTotal, PostingDate, CreatedAt)
    VALUES (@RunId, @Period, @EmployeeCount, @NetTotal, CAST(SYSDATETIME() AS DATE), SYSUTCDATETIME());
END
