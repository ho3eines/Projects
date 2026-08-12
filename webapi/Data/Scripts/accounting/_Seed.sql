-- =============================================
-- webapi/Data/Scripts/accounting/_Seed.sql
-- Schema: accounting
-- Endpoint: execute (startup, after _Ensure)
-- Safe to re-run.
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE DocumentNumber = N'SEED-001')
BEGIN
    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy)
    VALUES
        (N'SEED-001', CAST(SYSUTCDATETIME() AS DATE), N'Journal', N'شرکت نمونه', 1500000, N'IRR', N'Draft', N'seed'),
        (N'SEED-002', CAST(SYSUTCDATETIME() AS DATE), N'Payment', N'فروشگاه تست', 850000, N'IRR', N'Draft', N'seed');
END
