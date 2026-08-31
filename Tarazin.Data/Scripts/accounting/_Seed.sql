-- =============================================
-- Tarazin.Data/Scripts/accounting/_Seed.sql
-- Schema: accounting
-- Cross-schema: central
-- Endpoint: execute (startup)
-- =============================================
-- Seed برای EVERY active company (multi-company).
-- ترتیب اجرا (DbService.SeedAsync): central → accounting → inventory → goldshop → ...
-- پس Companies و FiscalYears در اینجا همیشه پر هستند.

DECLARE acc_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @SeedCompanyId INT;
DECLARE @SeedFiscalYearId INT;
OPEN acc_cursor;
FETCH NEXT FROM acc_cursor INTO @SeedCompanyId;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SeedFiscalYearId = (
        SELECT TOP 1 FiscalYearId FROM [central].[FiscalYears]
        WHERE CompanyId = @SeedCompanyId AND IsDeleted = 0 ORDER BY FiscalYearId);

    -- ⚠ ترتیب مهم است: ردیف‌های سند (DocumentLines) با CROSS JOIN به
    -- ChartOfAccounts ساخته می‌شوند؛ اگر ابتدا حساب‌ها seed نشوند، آن CROSS JOIN
    -- صفر ردیف برمی‌گرداند و سند نمونه «بدون ردیف» می‌ماند. پس اول حساب‌ها، بعد سند.

    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'1000', N'صندوق',              N'Asset',    1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'1010', N'بانک‌ها',             N'Asset',    1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'1020', N'موجودی کالا',         N'Asset',    1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'2000', N'حساب‌های پرداختنی',  N'Liability',1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'3000', N'سرمایه',             N'Equity',   1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'4000', N'فروش',               N'Income',   1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'5000', N'هزینه حقوق',         N'Expense',  1, SYSUTCDATETIME(), @SeedCompanyId);
    END

    -- سند نمونهٔ Journal: گارد باید دقیقاً روی خودِ سند (CompanyId+FiscalYearId+شماره+نوع)
    -- باشد تا idempotent بماند. گاردِ «هر سندی از شرکت» اشتباه است؛ چون وقتی شرکت
    -- اسناد دیگری دارد (مثلاً Opening به شمارهٔ 00000001) و UX_Documents_Number روی
    -- (شرکت+سال+شماره) بدون توجه به نوع یکتاست، درجِ دوبارهٔ 00000001 خطای duplicate می‌دهد.
    -- گارد NULL-safe: برای شرکتی که سال مالی ندارد (@SeedFiscalYearId = NULL)،
    -- مقایسهٔ «= NULL» همیشه false است و سند هر اجرا دوباره درج می‌شد (خطای
    -- duplicate کلید یکتای UX_Documents_Number روی (شرکت+سال+شماره)).
    IF NOT EXISTS (
        SELECT 1 FROM [accounting].[Documents]
        WHERE CompanyId = @SeedCompanyId
          AND ((@SeedFiscalYearId IS NULL AND FiscalYearId IS NULL) OR (FiscalYearId = @SeedFiscalYearId))
          AND DocumentNumber = N'00000001'
          AND IsDeleted = 0)
    BEGIN
        INSERT INTO [accounting].[Documents] (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, CompanyId, FiscalYearId)
        VALUES
            (N'00000001', CAST(SYSDATETIME() AS DATE), N'Journal', N'شرکت نمونه', 250000000, N'IRR', N'Posted', N'seed', @SeedCompanyId, @SeedFiscalYearId);
    END

    -- Two balanced journal lines for the seeded document (بدهکار صندوق / بستانکار فروش).
    -- گارد فقط روی ردیف‌های همین سند نمونه است (نه سراسری) تا idempotent بماند.
    -- همانطور گارد NULL-safe (مخصوص شرکت‌های بدون سال مالی).
    IF NOT EXISTS (
        SELECT 1 FROM [accounting].[DocumentLines] dl
        JOIN [accounting].[Documents] d ON d.DocumentId = dl.DocumentId
        WHERE d.CompanyId = @SeedCompanyId
          AND ((@SeedFiscalYearId IS NULL AND d.FiscalYearId IS NULL) OR (d.FiscalYearId = @SeedFiscalYearId))
          AND d.DocumentNumber = N'00000001')
    BEGIN
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT d.DocumentId, a.AccountId, a.AccountCode, a.Title, N'درآمد فروش', 250000000, 0
        FROM [accounting].[Documents] d
        CROSS JOIN [accounting].[ChartOfAccounts] a
        WHERE d.DocumentNumber = N'00000001' AND d.CompanyId = @SeedCompanyId AND a.AccountCode = N'1000' AND a.CompanyId = @SeedCompanyId;

        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT d.DocumentId, a.AccountId, a.AccountCode, a.Title, N'درآمد فروش', 0, 250000000
        FROM [accounting].[Documents] d
        CROSS JOIN [accounting].[ChartOfAccounts] a
        WHERE d.DocumentNumber = N'00000001' AND d.CompanyId = @SeedCompanyId AND a.AccountCode = N'4000' AND a.CompanyId = @SeedCompanyId;
    END

    -- حساب‌های ویژهٔ ماژول ارز و معاملات ارزی (PRD §34–§63) — افزودنی امن
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1030' AND IsDeleted = 0 AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt, CompanyId)
        VALUES (N'1030', N'موجودی ارز', N'Asset', 1, SYSUTCDATETIME(), @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1040' AND IsDeleted = 0 AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt, CompanyId)
        VALUES (N'1040', N'موجودی طلا و سکه', N'Asset', 1, SYSUTCDATETIME(), @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6000' AND IsDeleted = 0 AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt, CompanyId)
        VALUES (N'6000', N'سود و زیان تسعیر ارز', N'Income', 1, SYSUTCDATETIME(), @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6100' AND IsDeleted = 0 AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt, CompanyId)
        VALUES (N'6100', N'کارمزد و سایر هزینه‌ها', N'Expense', 1, SYSUTCDATETIME(), @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[TaxRules] WHERE CompanyId = @SeedCompanyId)
    BEGIN
        INSERT INTO [accounting].[TaxRules] (RuleCode, Title, Category, RatePercent, EffectiveFrom, IsActive, CreatedAt, CompanyId)
        VALUES
            (N'VAT-01',   N'مالیات بر ارزش افزوده',     N'Vat',     10.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'PAY-01',   N'مالیات بر حقوق',            N'Payroll', 10.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'GOLD-01',  N'مالیات طلا (اجرت و سود)',   N'Gold',     9.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME(), @SeedCompanyId),
            (N'COM-01',   N'حق الثبت و عوارض فروش',     N'Commerce', 1.0000, CAST('2026-01-01' AS DATE), 1, SYSUTCDATETIME(), @SeedCompanyId);
    END

    -- =============================================
    -- گروه‌های حساب برای طلافروشی (Detil) — مشتریان / تأمین‌کنندگان
    -- =============================================
    IF NOT EXISTS (SELECT 1 FROM [accounting].[AccountGroups] WHERE CompanyId = @SeedCompanyId AND GroupType = N'Detil' AND GroupCode = N'01')
        INSERT INTO [accounting].[AccountGroups] (GroupType, GroupCode, Title, FromCode, ToCode, DefaultNature, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'Detil', N'01', N'مشتریان', N'2000000', N'2999999', N'Debit', N'حساب‌های دریافتنی از مشتریان طلافروشی', 1, N'seed', @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[AccountGroups] WHERE CompanyId = @SeedCompanyId AND GroupType = N'Detil' AND GroupCode = N'02')
        INSERT INTO [accounting].[AccountGroups] (GroupType, GroupCode, Title, FromCode, ToCode, DefaultNature, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'Detil', N'02', N'تأمین‌کنندگان', N'3000000', N'3999999', N'Credit', N'حساب‌های پرداختنی به تأمین‌کنندگان طلافروشی', 1, N'seed', @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[AccountGroups] WHERE CompanyId = @SeedCompanyId AND GroupType = N'Detil' AND GroupCode = N'03')
        INSERT INTO [accounting].[AccountGroups] (GroupType, GroupCode, Title, FromCode, ToCode, DefaultNature, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'Detil', N'03', N'موجودی کالا', N'1100000', N'1199999', N'Debit', N'تفصیلی‌های موجودی کالا و طلا (خودکار)', 1, N'seed', @SeedCompanyId);

    -- =============================================
    -- Seed ریشه‌های جداول پایهٔ چندسطحی — Idempotent
    --   10 - دارایی‌ها / 001 - دارایی جاری / 0000001 - بانک‌ها
    --   20 - بدهی‌ها / 001 - بدهی‌های جاری
    --   30 - درآمدها / 001 - درآمد عملیاتی
    --   40 - هزینه‌ها / 001 - هزینه‌های عملیاتی
    -- =============================================

    -- Cols
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'10' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'10', N'دارایی‌ها', N'شامل دارایی‌های جاری و ثابت', 1, N'seed', @SeedCompanyId);
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'20' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'20', N'بدهی‌ها', N'شامل بدهی‌های جاری و بلندمدت', 1, N'seed', @SeedCompanyId);
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'30' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseCol] (ColCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'30', N'درآمدها', N'درآمدهای عملیاتی و غیرعملیاتی', 1, N'seed', @SeedCompanyId);
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseCol] WHERE ColCode = N'40' AND CompanyId = @SeedCompanyId)
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
    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000123' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'0000123', N'بانک ملی', N'حساب جاری ۱۲۳ نزد بانک ملی ایران', 1, N'seed', @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000456' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'0000456', N'بانک ملت', N'حساب جاری ۴۵۶ نزد بانک ملت', 1, N'seed', @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000789' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'0000789', N'بانک صادرات', N'حساب جاری ۷۸۹ نزد بانک صادرات', 1, N'seed', @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000001' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'0000001', N'بانک‌ها', N'دسته‌بندی حساب‌های بانکی', 1, N'seed', @SeedCompanyId);

    IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = N'0000002' AND CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[BaseDetil] (DetilCode, Title, [Description], IsActive, CreatedBy, CompanyId)
        VALUES (N'0000002', N'صندوق اصلی', N'صندوق فروشگاه مرکزی', 1, N'seed', @SeedCompanyId);

    -- DetilLinks (همان تفصیلی در مسیرهای مختلف)
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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000001'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'10'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000123'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'10'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000456'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'10'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000789'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'10'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000123'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'20'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000123'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'30'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

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
        WHERE d.CompanyId = @SeedCompanyId -- شرکتِ خودِ تفصیلی (جلوگیری از انفجار چندشرکتی)
          AND d.DetilCode = N'0000002'
          AND c.CompanyId = @SeedCompanyId
          AND c.ColCode   = N'40'
          AND m.MoeinCode = N'001'
          AND m.ColId     = c.ColId;

    -- گروه‌های تفصیلی به معین پیش‌فرض خود وصل می‌شوند (auto-link تفصیلی‌ها):
    --   مشتریان ← دارایی جاری (10/001) ، تأمین‌کنندگان ← بدهی‌های جاری (20/001)
    --   موجودی کالا ← دارایی جاری (10/001)
    UPDATE g
    SET g.DefaultMoeinId = m.MoeinId
    FROM [accounting].[AccountGroups] g
    JOIN [accounting].[BaseMoein] m ON m.CompanyId = @SeedCompanyId
    JOIN [accounting].[BaseCol] c   ON c.ColId = m.ColId AND c.CompanyId = @SeedCompanyId
    WHERE g.CompanyId = @SeedCompanyId AND g.GroupType = N'Detil' AND g.IsDeleted = 0
      AND ((g.GroupCode = N'01' AND c.ColCode = N'10' AND m.MoeinCode = N'001')
        OR (g.GroupCode = N'02' AND c.ColCode = N'20' AND m.MoeinCode = N'001')
        OR (g.GroupCode = N'03' AND c.ColCode = N'10' AND m.MoeinCode = N'001'));

    -- تنظیمات سراسری شرکت (گروه‌های تفصیلی مشترک): اگر هنوز ثبت نشده، با گروه‌های پیش‌فرض ساخته می‌شود
    IF NOT EXISTS (SELECT 1 FROM [accounting].[CompanyAccountSettings] WHERE CompanyId = @SeedCompanyId)
        INSERT INTO [accounting].[CompanyAccountSettings]
            (CompanyId, CustomerAccountGroupId, SupplierAccountGroupId, InventoryAccountGroupId, UpdatedAt, UpdatedBy)
        SELECT @SeedCompanyId,
               (SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@SeedCompanyId AND GroupType=N'Detil' AND GroupCode=N'01'),
               (SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@SeedCompanyId AND GroupType=N'Detil' AND GroupCode=N'02'),
               (SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@SeedCompanyId AND GroupType=N'Detil' AND GroupCode=N'03'),
               SYSUTCDATETIME(), N'seed';

    FETCH NEXT FROM acc_cursor INTO @SeedCompanyId;
END
CLOSE acc_cursor;
DEALLOCATE acc_cursor;
