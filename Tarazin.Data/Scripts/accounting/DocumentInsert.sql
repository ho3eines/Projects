-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentInsert.sql
-- Schema: accounting
-- Execute. ثبت سند حسابداری (سند روزنامه).
-- @LinesJson: آرایهٔ JSON از ردیف‌های بدهکار/بستانکار.
-- AccountId می‌تواند به BaseDetil / BaseMoein / BaseCol / ChartOfAccounts اشاره کند.
-- AccountCode به‌صورت ColCode+MoeinCode+DetilCode ترکیب می‌شود.
-- بهینه‌سازی:
--   1. ابتدا فقط مجموع را می‌خوانیم (بدون join سنگین).
--   2. سپس در یک INSERT با OUTER APPLY به جداول پایه (با ایندکس‌های FK)
--      AccountCode محاسبه و درج می‌شود.
--   3. واکشی BaseDetil/BaseMoein/BaseCol روی ستون PK برابر است و optimizer
--      خودش clustered seek می‌گیرد؛ برای BaseDetilLink از ایندکس پوششی
--      IX_BaseDetilLink_Detil_Active استفاده می‌شود.
-- توجه: PK این جداول در _Ensure.sql به‌صورت inline تعریف شده و نام خودکار
-- دارد (نه PK_BaseDetil و…)؛ بنابراین از hint ایندکس PK استفاده نکنید.
-- =============================================
IF @LinesJson IS NULL OR LEN(@LinesJson) = 0
    THROW 51040, N'حداقل یک ردیف سند الزامی است', 1;

-- مرحله ۱: بررسی توازن (بدون join سنگین)
DECLARE @TotalDebit DECIMAL(18,2), @TotalCredit DECIMAL(18,2);
SELECT
    @TotalDebit  = ISNULL(SUM(ISNULL(j.Debit, 0)), 0),
    @TotalCredit = ISNULL(SUM(ISNULL(j.Credit, 0)), 0)
FROM OPENJSON(@LinesJson)
WITH (
    AccountId   INT,
    AccountCode NVARCHAR(4000),
    Description NVARCHAR(500),
    Debit       DECIMAL(18,2),
    Credit      DECIMAL(18,2)
) j;

IF @TotalDebit <> @TotalCredit OR @TotalDebit <= 0
    THROW 51041, N'بدهی و بستانکاری سند برابر نیست', 1;

IF EXISTS (
    SELECT 1 FROM OPENJSON(@LinesJson)
    WITH (Debit DECIMAL(18,2), Credit DECIMAL(18,2)) j
    WHERE ISNULL(j.Debit, 0) < 0 OR ISNULL(j.Credit, 0) < 0
       OR (ISNULL(j.Debit, 0) = 0 AND ISNULL(j.Credit, 0) = 0)
       OR (ISNULL(j.Debit, 0) > 0 AND ISNULL(j.Credit, 0) > 0)
)
    THROW 51042, N'هر ردیف باید فقط یک مبلغ بدهکار یا بستانکار مثبت داشته باشد', 1;

DECLARE @DocDate DATE = CAST(@DocumentDate AS DATE);
DECLARE @CounterParty NVARCHAR(200) = NULLIF(@CounterPartyName, N'');

-- =============================================
-- Opening and Closing Document Business Rules
-- =============================================
IF @DocumentType = N'Opening'
BEGIN
    IF EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND DocumentType = N'Opening' AND IsDeleted = 0)
        THROW 51001, N'سند افتتاحیه برای این سال مالی قبلاً صادر شده است.', 1;

    IF EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0)
        THROW 51002, N'سند افتتاحیه باید اولین سند سال مالی باشد. در حال حاضر اسناد دیگری در این سال ثبت شده‌اند.', 1;
END

IF @DocumentType = N'Closing'
BEGIN
    IF EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND DocumentType = N'Closing' AND IsDeleted = 0)
        THROW 51003, N'سند اختتامیه برای این سال مالی قبلاً صادر شده است.', 1;

    IF NOT EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0)
        THROW 51004, N'سال مالی فاقد هرگونه سند برای ثبت اختتامیه است.', 1;
END

IF EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND DocumentType = N'Closing' AND IsDeleted = 0)
    THROW 51005, N'بعد از ثبت سند اختتامیه امکان ثبت سند جدید در این سال مالی وجود ندارد.', 1;

-- وضعیت اولیهٔ سند در چرخه: یادداشت | سند موقت.
-- سند تازه هرگز مستقیماً «تأیید شده»/«تأیید نهایی» ثبت نمی‌شود؛ برای آن باید
-- از DocumentStatusChange (با دسترسی مربوطه) استفاده شود.
-- @Status اختیاری است: اگر فراخوان آن را نفرستد/خالی بفرستد، «سند موقت».
DECLARE @InitialStatus NVARCHAR(50) =
    CASE WHEN LTRIM(RTRIM(ISNULL(@Status, N''))) = N'Note' THEN N'Note' ELSE N'Draft' END;

DECLARE @NextNum INT = 1;
IF @DocumentType = N'Opening'
BEGIN
    SET @NextNum = 1;
END
ELSE
BEGIN
    SELECT @NextNum = ISNULL(MAX(TRY_CONVERT(INT, d.DocumentNumber)), 0) + 1
    FROM [accounting].[Documents] d
    WHERE d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId AND d.IsDeleted = 0;
END

DECLARE @DocNum NVARCHAR(50) = RIGHT('00000000' + CAST(@NextNum AS NVARCHAR(10)), 8);

BEGIN TRAN;
    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
    VALUES
        (@DocNum, @DocDate, @DocumentType, @CounterParty, @TotalDebit, N'IRR', @InitialStatus, SYSUTCDATETIME(), @CreatedBy, 0, @CompanyId, @FiscalYearId);

    DECLARE @Did INT = SCOPE_IDENTITY();

    -- مرحله ۲: درج ردیف‌ها با resolve به جدول BaseDetil/Moein/Col
    -- هر join با ایندکس PK یا ایندکس‌های پوششی سریع است.
    ;WITH Lines AS (
        SELECT
            j.AccountId,
            NULLIF(LTRIM(RTRIM(j.AccountCode)), N'') AS AccountCode,
            j.Description,
            j.Debit,
            j.Credit
        FROM OPENJSON(@LinesJson)
        WITH (
            AccountId   INT,
            AccountCode NVARCHAR(4000),
            Description NVARCHAR(500),
            Debit       DECIMAL(18,2),
            Credit      DECIMAL(18,2)
        ) j
    ),
    DetailPaths AS (
        SELECT
            dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId, bd.Title,
            CAST(c.ColCode + m.MoeinCode + bd.DetilCode AS NVARCHAR(4000)) AS AccountCode
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN [accounting].[BaseMoein] m ON m.MoeinId = dl.MoeinId AND m.IsDeleted = 0
        INNER JOIN [accounting].[BaseCol] c ON c.ColId = m.ColId AND c.IsDeleted = 0
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0

        UNION ALL

        SELECT
            dl.LinkId, dl.ParentLinkId, dl.MoeinId, dl.DetilId, bd.Title,
            CAST(parent.AccountCode + bd.DetilCode AS NVARCHAR(4000))
        FROM [accounting].[BaseDetilLink] dl
        INNER JOIN DetailPaths parent ON parent.LinkId = dl.ParentLinkId AND parent.MoeinId = dl.MoeinId
        INNER JOIN [accounting].[BaseDetil] bd ON bd.DetilId = dl.DetilId AND bd.IsDeleted = 0
        WHERE dl.IsDeleted = 0
    ),
    Resolved AS (
        SELECT
            l.AccountId, l.Description, l.Debit, l.Credit,
            CASE WHEN LEN(l.AccountCode) >= 12 THEN exactPath.DetilId
                 WHEN l.AccountCode IS NOT NULL THEN legacyExact.AccountId
                 ELSE COALESCE(d.DetilId, m.MoeinId, c.ColId, coa.AccountId) END AS ResolvedAccountId,
            CASE WHEN LEN(l.AccountCode) >= 12 THEN exactPath.AccountCode
                 WHEN l.AccountCode IS NOT NULL THEN legacyExact.AccountCode
                 ELSE COALESCE(c.ColCode + m.MoeinCode + d.DetilCode,
                               c.ColCode + m.MoeinCode, c.ColCode, coa.AccountCode) END AS ResolvedAccountCode,
            CASE WHEN LEN(l.AccountCode) >= 12 THEN exactPath.Title
                 WHEN l.AccountCode IS NOT NULL THEN legacyExact.Title
                 ELSE COALESCE(d.Title, m.Title, c.Title, coa.Title) END AS ResolvedTitle
        FROM Lines l
        OUTER APPLY (
            SELECT TOP (1) p.DetilId, p.AccountCode, p.Title
            FROM DetailPaths p
            WHERE p.DetilId = l.AccountId AND p.AccountCode = l.AccountCode
            ORDER BY p.LinkId
        ) exactPath
        OUTER APPLY (
            SELECT TOP (1) co.AccountId, co.AccountCode, co.Title
            FROM [accounting].[ChartOfAccounts] co
            WHERE LEN(l.AccountCode) < 12
              AND co.AccountId = l.AccountId AND co.AccountCode = l.AccountCode
              AND co.IsDeleted = 0
        ) legacyExact
        OUTER APPLY (
            SELECT TOP 1 bd.DetilId, bd.DetilCode, bd.Title
            FROM [accounting].[BaseDetil] bd
            WHERE l.AccountCode IS NULL AND bd.DetilId = l.AccountId AND bd.IsDeleted = 0
        ) d
        OUTER APPLY (
            SELECT TOP 1 dl.MoeinId
            FROM [accounting].[BaseDetilLink] dl
            WHERE dl.DetilId = d.DetilId AND dl.IsDeleted = 0
            ORDER BY dl.LinkId
        ) dl
        OUTER APPLY (
            SELECT TOP 1 mm.MoeinId, mm.MoeinCode, mm.Title, mm.ColId
            FROM [accounting].[BaseMoein] mm
            WHERE mm.MoeinId = COALESCE(dl.MoeinId, l.AccountId) AND mm.IsDeleted = 0
        ) m
        OUTER APPLY (
            SELECT TOP 1 cc.ColId, cc.ColCode, cc.Title
            FROM [accounting].[BaseCol] cc
            WHERE cc.ColId = COALESCE(m.ColId, l.AccountId) AND cc.IsDeleted = 0
        ) c
        OUTER APPLY (
            SELECT TOP 1 co.AccountId, co.AccountCode, co.Title
            FROM [accounting].[ChartOfAccounts] co
            WHERE co.AccountId = l.AccountId AND co.IsDeleted = 0
        ) coa
    )
INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
SELECT
    @Did,
    r.ResolvedAccountId,
    r.ResolvedAccountCode,
    r.ResolvedTitle,
    r.Description,
    ISNULL(r.Debit, 0),
    ISNULL(r.Credit, 0)
FROM Resolved r
WHERE r.ResolvedAccountId IS NOT NULL
OPTION (MAXRECURSION 32767);

    DECLARE @InsertedLines INT = @@ROWCOUNT;
    DECLARE @ExpectedLines INT = (SELECT COUNT(*) FROM OPENJSON(@LinesJson));
    IF @InsertedLines <> @ExpectedLines
    BEGIN
        ROLLBACK;
        THROW 51044, N'حساب نامعتبر در ردیف‌های سند', 1;
    END
COMMIT;
