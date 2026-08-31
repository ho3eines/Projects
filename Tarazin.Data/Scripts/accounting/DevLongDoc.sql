-- =============================================
-- DevLongDoc.sql — ad-hoc: seed یک سند بسیار بلند (۳۲+ ردیف) برای تست چندصفحه‌گی چاپ A5
-- روی اولین شرکت/سال فعال. Idempotent به ازای DocumentNumber ثابت.
-- =============================================
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CompanyId INT = (SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted = 0 ORDER BY CompanyId);
DECLARE @FiscalYearId INT = (SELECT TOP 1 FiscalYearId FROM [central].[FiscalYears]
                              WHERE CompanyId = @CompanyId AND IsDeleted = 0 ORDER BY FiscalYearId);
DECLARE @DocNumber NVARCHAR(50) = N'90000001';
DECLARE @DocId INT;

-- delete existing (idempotent re-run)
SELECT @DocId = DocumentId FROM accounting.Documents
WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND DocumentNumber = @DocNumber;
IF @DocId IS NOT NULL BEGIN
    DELETE FROM accounting.DocumentLines WHERE DocumentId = @DocId;
    DELETE FROM accounting.Documents WHERE DocumentId = @DocId;
END

INSERT INTO accounting.Documents (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, [Status], CreatedBy, CompanyId, FiscalYearId)
VALUES (@DocNumber, CAST(SYSDATETIME() AS DATE), N'Journal', N'سند تست چندصفحه A5', 636000000, N'IRR', N'Posted', N'dev', @CompanyId, @FiscalYearId);
SET @DocId = SCOPE_IDENTITY();

DECLARE @DAccId INT = (SELECT TOP 1 AccountId FROM accounting.ChartOfAccounts WHERE CompanyId = @CompanyId AND AccountCode = N'1000');
DECLARE @CAccId INT = (SELECT TOP 1 AccountId FROM accounting.ChartOfAccounts WHERE CompanyId = @CompanyId AND AccountCode = N'1010');

DECLARE @i INT = 1;
WHILE @i <= 16
BEGIN
    INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, [Description], Debit, Credit)
    VALUES (@DocId, @DAccId, N'1000', N'صندوق',
            N'ردیف بلند ' + CAST(@i AS NVARCHAR(3)) + N' — شرح تستی برای چندصفحه‌گی در چاپ A5 سند حسابداری (ساده/پیشرفته).',
            CASE WHEN @i % 2 = 1 THEN 10000000 + @i * 1000000 ELSE 0 END, 0);

    INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, [Description], Debit, Credit)
    VALUES (@DocId, @CAccId, N'1010', N'بانک‌ها',
            N'بستانکار ردیف ' + CAST(@i AS NVARCHAR(3)) + N' — مانند قبل جهت توازن سند.',
            0, CASE WHEN @i % 2 = 1 THEN 10000000 + @i * 1000000 ELSE 0 END);
    SET @i = @i + 1;
END

SELECT N'LongDoc seeded' AS Info, @CompanyId AS CompanyId, @DocId AS DocId,
       (SELECT COUNT(*) FROM accounting.DocumentLines WHERE DocumentId = @DocId) AS Lines;
SELECT Debit = SUM(ISNULL(Debit,0)), Credit = SUM(ISNULL(Credit,0)) FROM accounting.DocumentLines WHERE DocumentId = @DocId;