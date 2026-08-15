-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentUpdate.sql
-- Schema: accounting
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
WHERE d.DocumentId = @DocumentId AND d.IsDeleted = 0;

IF @CurrentStatus IS NULL
    THROW 51045, N'سند پیدا نشد یا قبلاً حذف شده است', 1;

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
    Description NVARCHAR(500),
    Debit       DECIMAL(18,2),
    Credit      DECIMAL(18,2)
) j;

IF @TotalDebit <> @TotalCredit OR @TotalDebit <= 0
    THROW 51041, N'بدهی و بستانکاری سند برابر نیست', 1;

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
    WHERE DocumentId = @DocumentId AND IsDeleted = 0;

    -- ردیف‌های قبلی جایگزین می‌شوند (همان قرارداد فرم ثبت سند).
    DELETE FROM [accounting].[DocumentLines] WHERE DocumentId = @DocumentId;

    ;WITH Lines AS (
        SELECT
            j.AccountId,
            j.Description,
            j.Debit,
            j.Credit
        FROM OPENJSON(@LinesJson)
        WITH (
            AccountId   INT,
            Description NVARCHAR(500),
            Debit       DECIMAL(18,2),
            Credit      DECIMAL(18,2)
        ) j
    ),
Resolved AS (
    SELECT
        l.AccountId,
        l.Description,
        l.Debit,
        l.Credit,
        COALESCE(d.DetilId, m.MoeinId, c.ColId, coa.AccountId) AS ResolvedAccountId,
        COALESCE(c.ColCode + m.MoeinCode + d.DetilCode,
                 c.ColCode + m.MoeinCode,
                 c.ColCode,
                 coa.AccountCode) AS ResolvedAccountCode,
        COALESCE(d.Title, m.Title, c.Title, coa.Title) AS ResolvedTitle
    FROM Lines l
    OUTER APPLY (
        SELECT TOP 1 bd.DetilId, bd.DetilCode, bd.Title
        FROM [accounting].[BaseDetil] bd
        WHERE bd.DetilId = l.AccountId AND bd.IsDeleted = 0
    ) d
    OUTER APPLY (
        SELECT TOP 1 dl.MoeinId
        FROM [accounting].[BaseDetilLink] dl
        WHERE dl.DetilId = d.DetilId AND dl.IsDeleted = 0
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
    @DocumentId,
    r.ResolvedAccountId,
    r.ResolvedAccountCode,
    r.ResolvedTitle,
    r.Description,
    ISNULL(r.Debit, 0),
    ISNULL(r.Credit, 0)
FROM Resolved r
WHERE r.ResolvedAccountId IS NOT NULL;

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 51044, N'حساب نامعتبر در ردیف‌های سند', 1;
    END
COMMIT;
