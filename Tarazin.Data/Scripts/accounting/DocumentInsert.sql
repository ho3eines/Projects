-- =============================================
-- Tarazin.Data/Scripts/accounting/DocumentInsert.sql
-- Schema: accounting
-- Execute. ثبت سند حسابداری (سند روزنامه) — سربرگ + ردیف‌های بدهکار/بستانکار.
-- Rows arrive as a JSON array in @LinesJson, e.g.
--   [ { "AccountId":1, "Description":"...", "Debit":100, "Credit":0 }, ... ]
-- AccountId می‌تواند به یکی از این سه جدول اشاره کند:
--   - BaseDetil (تشخیص اولویت: تراکنش فقط روی تفصیلی)
--   - BaseMoein
--   - BaseCol
-- AccountCode در DocumentLines به‌صورت ترکیب مسیر ذخیره می‌شود (Col+Moein+Detil).
-- Validates that debit == credit (double-entry) before committing.
-- =============================================
IF @LinesJson IS NULL OR LEN(@LinesJson) = 0
    THROW 51040, N'حداقل یک ردیف سند الزامی است', 1;

DECLARE @TotalDebit DECIMAL(18,2) = 0, @TotalCredit DECIMAL(18,2) = 0, @BadAccount INT = 0;

-- ابتدا فقط مجموع و تعداد نامعتبر را محاسبه می‌کنیم
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

    -- درج ردیف‌ها: AccountId از JSON می‌تواند به BaseDetil (اولویت) / BaseMoein / BaseCol / ChartOfAccounts اشاره کند.
    -- اگر به BaseDetil اشاره داشت، AccountCode = ColCode+MoeinCode+DetilCode
    -- اگر به BaseMoein اشاره داشت، AccountCode = ColCode+MoeinCode
    -- اگر به BaseCol اشاره داشت، AccountCode = ColCode
    -- در غیر این صورت (AccountId در ChartOfAccounts قدیمی)، از همان استفاده می‌شود.
    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT
        @Did,
        COALESCE(d.DetilId, m.MoeinId, c.ColId, coa.AccountId) AS AccountId,
        COALESCE(c.ColCode + m.MoeinCode + d.DetilCode,
                 c.ColCode + m.MoeinCode,
                 c.ColCode,
                 coa.AccountCode) AS AccountCode,
        COALESCE(d.Title, m.Title, c.Title, coa.Title) AS Title,
        j.Description,
        ISNULL(j.Debit, 0),
        ISNULL(j.Credit, 0)
    FROM OPENJSON(@LinesJson)
    WITH (
        AccountId   INT,
        Description NVARCHAR(500),
        Debit       DECIMAL(18,2),
        Credit      DECIMAL(18,2)
    ) j
    OUTER APPLY (SELECT TOP 1 * FROM [accounting].[BaseDetil] bd WHERE bd.DetilId = j.AccountId AND bd.IsDeleted = 0) d
    OUTER APPLY (SELECT TOP 1 * FROM [accounting].[BaseDetilLink] dl WHERE dl.DetilId = d.DetilId AND dl.IsDeleted = 0) dl
    OUTER APPLY (SELECT TOP 1 * FROM [accounting].[BaseMoein] m WHERE m.MoeinId = COALESCE(dl.MoeinId, j.AccountId) AND m.IsDeleted = 0) m
    OUTER APPLY (SELECT TOP 1 * FROM [accounting].[BaseCol]   c WHERE c.ColId   = COALESCE(m.ColId, j.AccountId) AND c.IsDeleted = 0) c
    OUTER APPLY (SELECT TOP 1 * FROM [accounting].[ChartOfAccounts] coa WHERE coa.AccountId = j.AccountId AND coa.IsDeleted = 0) coa
    WHERE COALESCE(d.DetilId, m.MoeinId, c.ColId, coa.AccountId) IS NOT NULL;

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 51044, N'حساب نامعتبر در ردیف‌های سند', 1;
    END
COMMIT;
