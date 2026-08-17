-- =============================================
-- Tarazin.Data/Scripts/accounting/_Seed.sql
-- Schema: accounting
-- Cross-schema: central
-- Endpoint: execute (startup)
-- =============================================
-- شرکت/سال مالی پیش‌فرض: seed اسکیمای central اول اجرا می‌شود (ترتیب SeedAsync)،
-- پس این مقدارها همیشه پر هستند؛ در غیر این صورت بک‌فیل _Ensure در اجرای بعدی
-- داده‌های بدون مالک را به اولین شرکت فعال منتقل می‌کند.
DECLARE @SeedCompanyId INT = (
    SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
DECLARE @SeedFiscalYearId INT = (
    SELECT TOP 1 FiscalYearId FROM [central].[FiscalYears]
    WHERE CompanyId = @SeedCompanyId AND IsDeleted = 0 ORDER BY FiscalYearId);
-- ⚠ ترتیب مهم است (باگ تاریخی — رفع شد): ردیف‌های سند (DocumentLines) با
-- CROSS JOIN به ChartOfAccounts ساخته می‌شوند؛ اگر ابتدا حساب‌ها seed نشوند،
-- آن CROSS JOIN صفر ردیف برمی‌گرداند و سند نمونه «بدون ردیف» می‌ماند
-- (دفتر روزنامه/کل و تراز آزمایشی خالی می‌شدند). پس اول حساب‌ها، بعد سند.

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

IF NOT EXISTS (SELECT 1 FROM [accounting].[Documents])
BEGIN
    INSERT INTO [accounting].[Documents] (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, CompanyId, FiscalYearId)
    VALUES
        (N'00000001', CAST(SYSDATETIME() AS DATE), N'Journal', N'شرکت نمونه', 250000000, N'IRR', N'Posted', N'seed', @SeedCompanyId, @SeedFiscalYearId);
END

-- Two balanced journal lines for the seeded document (بدهکار صندوق / بستانکار فروش).
IF NOT EXISTS (SELECT 1 FROM [accounting].[DocumentLines])
BEGIN
    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT d.DocumentId, a.AccountId, a.AccountCode, a.Title, N'درآمد فروش', 250000000, 0
    FROM [accounting].[Documents] d
    CROSS JOIN [accounting].[ChartOfAccounts] a
    WHERE d.DocumentNumber = N'00000001' AND a.AccountCode = N'1000';

    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT d.DocumentId, a.AccountId, a.AccountCode, a.Title, N'درآمد فروش', 0, 250000000
    FROM [accounting].[Documents] d
    CROSS JOIN [accounting].[ChartOfAccounts] a
    WHERE d.DocumentNumber = N'00000001' AND a.AccountCode = N'4000';
END

-- حساب‌های ویژهٔ ماژول ارز و معاملات ارزی (PRD §34–§63) — افزودنی امن
-- برای دیتابیس‌های موجود (هر کد جداگانه بررسی می‌شود تا seed قدیمی را نشکند).
IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1030' AND IsDeleted = 0)
    INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
    VALUES (N'1030', N'موجودی ارز', N'Asset', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1040' AND IsDeleted = 0)
    INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
    VALUES (N'1040', N'موجودی طلا و سکه', N'Asset', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6000' AND IsDeleted = 0)
    INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
    VALUES (N'6000', N'سود و زیان تسعیر ارز', N'Income', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6100' AND IsDeleted = 0)
    INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
    VALUES (N'6100', N'کارمزد و سایر هزینه‌ها', N'Expense', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM [accounting].[TaxRules])
BEGIN
    INSERT INTO [accounting].[TaxRules] (RuleCode, Title, Category, RatePercent, EffectiveFrom, IsActive, CreatedAt)
    VALUES
        (N'VAT-01',   N'مالیات بر ارزش افزوده',     N'Vat',     10.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME()),
        (N'PAY-01',   N'مالیات بر حقوق',            N'Payroll', 10.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME()),
        (N'GOLD-01',  N'مالیات طلا (اجرت و سود)',   N'Gold',     9.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME()),
        (N'COM-01',   N'حق الثبت و عوارض فروش',     N'Commerce', 1.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME());
END

-- =============================================
-- Seed ریشه‌های جداول پایهٔ چندسطحی (PRD §جداول پایه) — Idempotent
-- ساختار نمونه:
--   10 - دارایی‌ها
--     001 - دارایی جاری
--       0000001 - بانک‌ها
--         0000123 - بانک ملی
--         0000456 - بانک ملت
--         0000789 - بانک صادرات
--   20 - بدهی‌ها
--     001 - بدهی‌های جاری
--       0000123 - بانک ملی (پیوند همان تفصیلی)
--   30 - درآمدها
--     001 - درآمد عملیاتی
--       0000123 - بانک ملی (پیوند همان تفصیلی)
--   40 - هزینه‌ها
--     001 - هزینه‌های عملیاتی
-- =============================================

-- Cols
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'10')
    INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'10', N'دارایی‌ها', N'شامل دارایی‌های جاری و ثابت', 1, N'seed', @SeedCompanyId);
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'20')
    INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'20', N'بدهی‌ها', N'شامل بدهی‌های جاری و بلندمدت', 1, N'seed', @SeedCompanyId);
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'30')
    INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'30', N'درآمدها', N'درآمدهای عملیاتی و غیرعملیاتی', 1, N'seed', @SeedCompanyId);
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'40')
    INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'40', N'هزینه‌ها', N'هزینه‌های عملیاتی و متفرقه', 1, N'seed', @SeedCompanyId);

-- Moeins
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
               WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'10' AND m.MoeinCode = N'001')
    INSERT INTO [accounting].[BaseMoein] (ColId, MoeinCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    SELECT ColId, N'001', N'دارایی جاری', N'شامل صندوق، بانک، موجودی کالا', 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseCol] WHERE CompanyId = @SeedCompanyId AND ColCode = N'10';

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
               WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'10' AND m.MoeinCode = N'002')
    INSERT INTO [accounting].[BaseMoein] (ColId, MoeinCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    SELECT ColId, N'002', N'دارایی ثابت', N'شامل اموال، ماشین‌آلات، ساختمان', 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseCol] WHERE CompanyId = @SeedCompanyId AND ColCode = N'10';

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
               WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'20' AND m.MoeinCode = N'001')
    INSERT INTO [accounting].[BaseMoein] (ColId, MoeinCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    SELECT ColId, N'001', N'بدهی‌های جاری', N'حساب‌های پرداختنی کوتاه‌مدت', 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseCol] WHERE CompanyId = @SeedCompanyId AND ColCode = N'20';

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
               WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'30' AND m.MoeinCode = N'001')
    INSERT INTO [accounting].[BaseMoein] (ColId, MoeinCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    SELECT ColId, N'001', N'درآمد عملیاتی', N'فروش کالا و خدمات', 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseCol] WHERE CompanyId = @SeedCompanyId AND ColCode = N'30';

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId
               WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'40' AND m.MoeinCode = N'001')
    INSERT INTO [accounting].[BaseMoein] (ColId, MoeinCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    SELECT ColId, N'001', N'هزینه‌های عملیاتی', N'شامل حقوق، اجاره، مواد', 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseCol] WHERE CompanyId = @SeedCompanyId AND ColCode = N'40';

-- Detils (تفصیلی‌های یکپارچه)
IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000123')
    INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'0000123', N'بانک ملی', N'حساب جاری ۱۲۳ نزد بانک ملی ایران', 1, N'seed', @SeedCompanyId);

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000456')
    INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'0000456', N'بانک ملت', N'حساب جاری ۴۵۶ نزد بانک ملت', 1, N'seed', @SeedCompanyId);

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000789')
    INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'0000789', N'بانک صادرات', N'حساب جاری ۷۸۹ نزد بانک صادرات', 1, N'seed', @SeedCompanyId);

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000001')
    INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'0000001', N'بانک‌ها', N'دسته‌بندی حساب‌های بانکی', 1, N'seed', @SeedCompanyId);

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000002')
    INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
    VALUES (N'0000002', N'صندوق اصلی', N'صندوق فروشگاه مرکزی', 1, N'seed', @SeedCompanyId);

-- DetilLinks
-- 10/001/0000001
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'10' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000001'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000001'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'10'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;

-- 10/001/0000001 → 0000123
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'10' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000123'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000123'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'10'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;

-- 10/001/0000001 → 0000456
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'10' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000456'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000456'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'10'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;

-- 10/001/0000001 → 0000789
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'10' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000789'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000789'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'10'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;

-- 20/001/0000123 (همان تفصیلی در مسیر دیگر)
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'20' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000123'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000123'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'20'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;

-- 30/001/0000123 (همان تفصیلی در مسیر سوم)
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'30' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000123'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000123'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'30'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;

-- 40/001/0000002
IF NOT EXISTS (
    SELECT 1 FROM [accounting].[BaseDetilLink] dl
    JOIN [accounting].[BaseDetil] d ON d.DetilId = dl.DetilId
    JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId
    JOIN [accounting].[BaseCol]   c ON c.ColId   = m.ColId
    WHERE c.CompanyId = @SeedCompanyId AND c.ColCode = N'40' AND m.MoeinCode = N'001' AND d.DetilCode = N'0000002'
)
    INSERT INTO [accounting].[BaseDetilLink] (DetilId, MoeinId, IsActive, CreatedBy, CompanyId)
    SELECT d.DetilId, m.MoeinId, 1, N'seed', @SeedCompanyId
    FROM [accounting].[BaseDetil] d, [accounting].[BaseMoein] m, [accounting].[BaseCol] c
    WHERE d.DetilCode = N'0000002'
      AND c.CompanyId = @SeedCompanyId
      AND c.ColCode   = N'40'
      AND m.MoeinCode = N'001'
      AND m.ColId     = c.ColId;
