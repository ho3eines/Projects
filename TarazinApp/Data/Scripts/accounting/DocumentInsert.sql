-- =============================================
-- TarazinApp/Data/Scripts/accounting/DocumentInsert.sql
-- Schema: accounting
-- Execute. ثبت سند حسابداری (سند روزنامه) — سربرگ + ردیف‌های بدهکار/بستانکار.
-- Rows arrive as a JSON array in @LinesJson, e.g.
--   [ { "AccountId":1, "Description":"...", "Debit":100, "Credit":0 }, ... ]
-- Validates that debit == credit (double-entry) before committing.
-- =============================================
IF @LinesJson IS NULL OR LEN(@LinesJson) = 0
    THROW 51040, N'حداقل یک ردیف سند الزامی است', 1;

DECLARE @TotalDebit DECIMAL(18,2) = 0, @TotalCredit DECIMAL(18,2) = 0, @BadAccount INT = 0;

SELECT
    @TotalDebit  = ISNULL(SUM(ISNULL(j.Debit, 0)), 0),
    @TotalCredit = ISNULL(SUM(ISNULL(j.Credit, 0)), 0),
    @BadAccount  = SUM(CASE WHEN a.AccountId IS NULL THEN 1 ELSE 0 END)
FROM OPENJSON(@LinesJson)
WITH (
    AccountId   INT,
    Description NVARCHAR(500),
    Debit       DECIMAL(18,2),
    Credit      DECIMAL(18,2)
) j
LEFT JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = j.AccountId AND a.IsDeleted = 0;

IF @BadAccount > 0
    THROW 51044, N'حساب نامعتبر در ردیف‌های سند', 1;
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

    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT @Did, a.AccountId, a.AccountCode, a.Title, j.Description, ISNULL(j.Debit, 0), ISNULL(j.Credit, 0)
    FROM OPENJSON(@LinesJson)
    WITH (
        AccountId   INT,
        Description NVARCHAR(500),
        Debit       DECIMAL(18,2),
        Credit      DECIMAL(18,2)
    ) j
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = j.AccountId AND a.IsDeleted = 0;
COMMIT;
