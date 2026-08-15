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
    Description NVARCHAR(500),
    Debit       DECIMAL(18,2),
    Credit      DECIMAL(18,2)
) j;

IF @TotalDebit <> @TotalCredit OR @TotalDebit <= 0
    THROW 51041, N'بدهی و بستانکاری سند برابر نیست', 1;

DECLARE @DocDate DATE = CAST(@DocumentDate AS DATE);
DECLARE @CounterParty NVARCHAR(200) = NULLIF(@CounterPartyName, N'');

BEGIN TRAN;
    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted)
    VALUES
        (N'', @DocDate, @DocumentType, @CounterParty, @TotalDebit, N'IRR', N'Posted', SYSUTCDATETIME(), @CreatedBy, 0);

    DECLARE @Did INT = SCOPE_IDENTITY();
    UPDATE [accounting].[Documents]
    SET DocumentNumber = N'DOC-' + RIGHT(N'00000' + CAST(@Did AS NVARCHAR(10)), 5)
    WHERE DocumentId = @Did;

    -- مرحله ۲: درج ردیف‌ها با resolve به جدول BaseDetil/Moein/Col
    -- هر join با ایندکس PK یا ایندکس‌های پوششی سریع است.
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
    @Did,
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
