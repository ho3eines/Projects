-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentUpdate.sql
-- Schema: accounting
-- Cross-schema: central
-- Execute. ویرایش سند حسابداری موجود (سربرگ + ردیف‌ها).
-- @LinesJson: آرایهٔ JSON از ردیف‌های بدهکار/بستانکار (جایگزین کامل ردیف‌های قبلی).
--
-- قانون: ویرایش فقط در وضعیت «یادداشت» (Note) و «سند موقت» (Draft) مجاز است.
-- در «تأیید شده» (Posted) و «تأیید نهایی» (Closed) سند فقط‌خواندنی است — این
-- کنترل در همین اسکریپت (نه فقط در UI) اعمال می‌شود تا با فراخوانی مستقیم هم
-- قابل دور زدن نباشد.
--
-- منطق resolve کردن حساب‌ها دقیقاً همان DocumentInsert.sql است تا AccountCode
-- ردیف‌ها با روال فعلی پروژه یکسان بماند.
-- =============================================
IF @LinesJson IS NULL OR LEN(@LinesJson) = 0
    THROW 51040, N'حداقل یک ردیف سند الزامی است', 1;

DECLARE @CurrentStatus NVARCHAR(50);

SELECT @CurrentStatus = d.Status
FROM [accounting].[Documents] d
WHERE d.DocumentId = @DocumentId AND d.IsDeleted = 0 AND d.CompanyId = @CompanyId AND d.FiscalYearId = @FiscalYearId;

IF @CurrentStatus IS NULL
    THROW 51045, N'سند پیدا نشد، قبلاً حذف شده است یا متعلق به این شرکت و سال مالی نیست', 1;

-- ویرایش سند در سال مالی بسته ممنوع است.
IF EXISTS (SELECT 1 FROM [central].[FiscalYears]
           WHERE FiscalYearId = @FiscalYearId AND CompanyId = @CompanyId
             AND ISNULL([Status], N'Open') = N'Closed')
    THROW 51006, N'سال مالی بسته شده است؛ امکان ویرایش سند وجود ندارد.', 1;

IF @CurrentStatus NOT IN (N'Note', N'Draft')
    THROW 51046, N'سند در وضعیت فعلی قابل ویرایش نیست (فقط یادداشت و سند موقت).', 1;

-- بررسی توازن
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

BEGIN TRAN;
    UPDATE [accounting].[Documents]
    SET DocumentDate     = @DocDate,
        DocumentType     = @DocumentType,
        CounterPartyName = @CounterParty,
        TotalAmount      = @TotalDebit,
        UpdatedAt        = SYSUTCDATETIME(),
        UpdatedBy        = @UpdatedBy
    WHERE DocumentId = @DocumentId AND IsDeleted = 0 AND CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId;

    -- ردیف‌های قبلی جایگزین می‌شوند (همان قرارداد فرم ثبت سند).
    DELETE FROM [accounting].[DocumentLines] WHERE DocumentId = @DocumentId;

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
        WHERE dl.ParentLinkId IS NULL AND dl.IsDeleted = 0 AND dl.CompanyId = @CompanyId

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
            WHERE l.AccountCode IS NULL AND bd.DetilId = l.AccountId AND bd.IsDeleted = 0 AND bd.CompanyId = @CompanyId
        ) d
        OUTER APPLY (
            SELECT TOP 1 dl.MoeinId
            FROM [accounting].[BaseDetilLink] dl
            WHERE dl.DetilId = d.DetilId AND dl.IsDeleted = 0 AND dl.CompanyId = @CompanyId
            ORDER BY dl.LinkId
        ) dl
        OUTER APPLY (
            SELECT TOP 1 mm.MoeinId, mm.MoeinCode, mm.Title, mm.ColId
            FROM [accounting].[BaseMoein] mm
            WHERE mm.MoeinId = COALESCE(dl.MoeinId, l.AccountId) AND mm.IsDeleted = 0 AND mm.CompanyId = @CompanyId
        ) m
        OUTER APPLY (
            SELECT TOP 1 cc.ColId, cc.ColCode, cc.Title
            FROM [accounting].[BaseCol] cc
            WHERE cc.ColId = COALESCE(m.ColId, l.AccountId) AND cc.IsDeleted = 0 AND cc.CompanyId = @CompanyId
        ) c
        OUTER APPLY (
            SELECT TOP 1 co.AccountId, co.AccountCode, co.Title
            FROM [accounting].[ChartOfAccounts] co
            WHERE co.AccountId = l.AccountId AND co.IsDeleted = 0
        ) coa
    )
INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
SELECT
    @DocumentId,
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
