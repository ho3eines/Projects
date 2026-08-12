-- =============================================
-- Tarazin.Data/Scripts/accounting/_Seed.sql
-- Schema: accounting
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [accounting].[Documents])
BEGIN
    INSERT INTO [accounting].[Documents] (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy)
    VALUES
        (N'DOC-00001', CAST(SYSDATETIME() AS DATE), N'Journal', N'شرکت نمونه', 250000000, N'IRR', N'Posted', N'seed');
END

-- Two balanced journal lines for the seeded document (بدهکار صندوق / بستانکار فروش).
IF NOT EXISTS (SELECT 1 FROM [accounting].[DocumentLines])
BEGIN
    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT d.DocumentId, a.AccountId, a.AccountCode, a.Title, N'درآمد فروش', 250000000, 0
    FROM [accounting].[Documents] d
    CROSS JOIN [accounting].[ChartOfAccounts] a
    WHERE d.DocumentNumber = N'DOC-00001' AND a.AccountCode = N'1000';

    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT d.DocumentId, a.AccountId, a.AccountCode, a.Title, N'درآمد فروش', 0, 250000000
    FROM [accounting].[Documents] d
    CROSS JOIN [accounting].[ChartOfAccounts] a
    WHERE d.DocumentNumber = N'DOC-00001' AND a.AccountCode = N'4000';
END

IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts])
BEGIN
    INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
    VALUES
        (N'1000', N'صندوق',              N'Asset',    1, SYSUTCDATETIME()),
        (N'1010', N'بانک‌ها',             N'Asset',    1, SYSUTCDATETIME()),
        (N'1020', N'موجودی کالا',         N'Asset',    1, SYSUTCDATETIME()),
        (N'2000', N'حساب‌های پرداختنی',  N'Liability',1, SYSUTCDATETIME()),
        (N'3000', N'سرمایه',             N'Equity',   1, SYSUTCDATETIME()),
        (N'4000', N'فروش',               N'Income',   1, SYSUTCDATETIME()),
        (N'5000', N'هزینه حقوق',         N'Expense',  1, SYSUTCDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM [accounting].[TaxRules])
BEGIN
    INSERT INTO [accounting].[TaxRules] (RuleCode, Title, Category, RatePercent, EffectiveFrom, IsActive, CreatedAt)
    VALUES
        (N'VAT-01',   N'مالیات بر ارزش افزوده',     N'Vat',     10.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME()),
        (N'PAY-01',   N'مالیات بر حقوق',            N'Payroll', 10.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME()),
        (N'GOLD-01',  N'مالیات طلا (اجرت و سود)',   N'Gold',     9.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME()),
        (N'COM-01',   N'حق الثبت و عوارض فروش',     N'Commerce', 1.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME());
END
