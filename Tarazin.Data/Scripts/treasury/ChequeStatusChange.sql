-- =============================================
-- Tarazin.Data/Scripts/treasury/ChequeStatusChange.sql
-- Schema: treasury | Cross-schema: central, accounting
-- Execute. تغییر وضعیت چک با ثبت تاریخ/دلیل و اثر مالی وصول.
--
-- چرخهٔ وضعیت:
--   Pending (در انتظار) → Collecting (در جریان) → Passed (وصول) / Returned (برگشتی)
--   Pending → Cancelled (لغو) | Voided (باطل — از برگشت فاکتور طلافروشی)
--
-- وصول چک دریافتی (In): اگر @CollectAccountId داده شود، حرکت خزانه (دریافت) و
-- سند حسابداری یاداشت ساخته می‌شود (بدهکار بانک ← بستانکار حساب مقابل دریافت).
-- =============================================
IF @Status NOT IN (N'Pending', N'Collecting', N'Passed', N'Returned', N'Cancelled', N'Voided')
    THROW 51023, N'وضعیت چک نامعتبر است.', 1;

IF NOT EXISTS (SELECT 1 FROM [treasury].[Cheques] WHERE ChequeId = @ChequeId AND CompanyId = @CompanyId)
    THROW 51024, N'چک یافت نشد.', 1;

DECLARE @CurrentStatus NVARCHAR(30) = (SELECT Status FROM [treasury].[Cheques] WHERE ChequeId = @ChequeId);
DECLARE @Direction NVARCHAR(10) = (SELECT Direction FROM [treasury].[Cheques] WHERE ChequeId = @ChequeId);
DECLARE @Amount DECIMAL(18,2) = (SELECT Amount FROM [treasury].[Cheques] WHERE ChequeId = @ChequeId);
DECLARE @ChequeNumber NVARCHAR(50) = (SELECT ChequeNumber FROM [treasury].[Cheques] WHERE ChequeId = @ChequeId);

-- اعتبارسنجی گذار:
--   Passed → Returned: برگشت چک وصول‌شده (اثر مالی معکوس حرکت خزانه و سند)
--   Returned/Cancelled/Voided: وضعیت‌های پایانی دیگر تغییر نمی‌کنند.
IF @CurrentStatus IN (N'Returned', N'Cancelled', N'Voided')
    THROW 51025, N'چک در وضعیت پایانی است و قابل تغییر نیست.', 1;

-- فقط چک در انتظار می‌تواند لغو/باطل شود؛ چک در جریان باید وصول یا برگشت بخورد.
IF @CurrentStatus = N'Collecting' AND @Status IN (N'Pending', N'Cancelled', N'Voided')
    THROW 51026, N'چک در جریان وصول است؛ فقط وصول یا برگشت ممکن است.', 1;

-- چک وصول‌شده فقط می‌تواند برگشت بخورد (با اثر مالی معکوس).
IF @CurrentStatus = N'Passed' AND @Status <> N'Returned'
    THROW 51028, N'چک وصول‌شده فقط می‌تواند برگشت بخورد.', 1;

BEGIN TRAN;

-- ── اثر مالی معکوس برگشت چک وصول‌شده (Passed → Returned):
--     حرکت خزانه و سند وصول، باطل و موجودی بانک برگردانده می‌شود. ──
IF @CurrentStatus = N'Passed' AND @Status = N'Returned' AND @Direction = N'In'
BEGIN
    DECLARE @SrcRef NVARCHAR(100) = CONCAT(N'Cheque:', @ChequeId);
    DECLARE @RevMovementId INT = NULL, @RevAccountId INT = NULL;

    -- ۱) حرکت خزانهٔ وصول را پیدا و باطل کن
    SELECT TOP (1) @RevMovementId = MovementId, @RevAccountId = AccountId
    FROM [treasury].[CashMovements]
    WHERE SourceReference = @SrcRef AND CompanyId = @CompanyId AND Status = N'Posted'
    ORDER BY MovementId DESC;

    IF @RevMovementId IS NOT NULL
    BEGIN
        UPDATE [treasury].[CashMovements]
        SET Status = N'Reversed', UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy,
            Description = N'برگشت وصول چک ' + @ChequeNumber
        WHERE MovementId = @RevMovementId;

        -- ۲) موجودی حساب بانکی را برگردان
        IF @RevAccountId IS NOT NULL
            UPDATE [treasury].[BankAccounts] SET Balance = Balance - @Amount
            WHERE AccountId = @RevAccountId AND CompanyId = @CompanyId;
    END

    -- ۳) سند حسابداری وصول را باطل کن
    UPDATE [accounting].[Documents]
    SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UpdatedBy
    WHERE SourceReference = @SrcRef AND CompanyId = @CompanyId AND IsDeleted = 0;
END

UPDATE [treasury].[Cheques]
SET Status = @Status,
    UpdatedAt = SYSUTCDATETIME(),
    UpdatedBy = @UpdatedBy,
    CollectedAt = CASE WHEN @Status = N'Passed' THEN SYSUTCDATETIME() ELSE CollectedAt END,
    ReturnedAt = CASE WHEN @Status = N'Returned' THEN SYSUTCDATETIME() ELSE ReturnedAt END,
    ReturnReason = CASE WHEN @Status = N'Returned' THEN @Reason ELSE ReturnReason END
WHERE ChequeId = @ChequeId AND CompanyId = @CompanyId;

-- ── اثر مالی وصول چک دریافتی (In): حرکت خزانه + سند حسابداری ──
IF @Status = N'Passed' AND @Direction = N'In' AND @CollectAccountId IS NOT NULL
BEGIN
    DECLARE @FundAccountId INT = NULL, @FundCode NVARCHAR(4000) = NULL, @FundTitle NVARCHAR(200) = NULL;
    SELECT @FundAccountId = BankChartAccountId, @FundCode = BankChartAccountCode, @FundTitle = BankChartAccountTitle
    FROM [treasury].[TreasurySettings] WHERE CompanyId = @CompanyId;

    IF @FundAccountId IS NULL OR @FundCode IS NULL
    BEGIN
        ROLLBACK;
        THROW 51027, N'حساب بانکی در تنظیمات اتصال خزانه تنظیم نشده است.', 1;
    END

    -- ۱) حرکت خزانه
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId,
         Description, SourceReference, Status, CreatedBy, CompanyId)
    VALUES
        (N'', CAST(SYSDATETIME() AS DATE), N'In', @Amount, N'IRR', @CollectAccountId, NULL,
         N'وصول چک ' + @ChequeNumber, CONCAT(N'Cheque:', @ChequeId), N'Posted', @UpdatedBy, @CompanyId);

    DECLARE @Mid INT = SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements]
    SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5)
    WHERE MovementId = @Mid;

    -- ۲) موجودی حساب بانکی
    UPDATE [treasury].[BankAccounts] SET Balance = Balance + @Amount WHERE AccountId = @CollectAccountId AND CompanyId = @CompanyId;

    -- ۳) سند حسابداری یاداشت (اگر سال مالی داده شود)
    IF @FiscalYearId IS NOT NULL
    BEGIN
        DECLARE @ContraAccountId INT = NULL, @ContraCode NVARCHAR(4000) = NULL, @ContraTitle NVARCHAR(200) = NULL;
        SELECT @ContraAccountId = ReceiveContraAccountId, @ContraCode = ReceiveContraAccountCode, @ContraTitle = ReceiveContraAccountTitle
        FROM [treasury].[TreasurySettings] WHERE CompanyId = @CompanyId;

        IF @ContraAccountId IS NOT NULL AND @ContraCode IS NOT NULL
        BEGIN
            DECLARE @MovementNumber NVARCHAR(50) = (SELECT MovementNumber FROM [treasury].[CashMovements] WHERE MovementId = @Mid);
            DECLARE @NextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber))
                                           FROM [accounting].[Documents]
                                           WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;

            INSERT INTO [accounting].[Documents]
                (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId, SourceReference)
            VALUES
                (RIGHT(N'00000000' + CAST(@NextNum AS NVARCHAR(10)), 8), CAST(SYSDATETIME() AS DATE),
                 N'TreasuryIn', N'وصول چک ' + @ChequeNumber, @Amount, N'IRR',
                 N'Note', @UpdatedBy, 0, @CompanyId, @FiscalYearId, CONCAT(N'Cheque:', @ChequeId));
            DECLARE @DocumentId INT = SCOPE_IDENTITY();

            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            VALUES (@DocumentId, @FundAccountId, @FundCode, @FundTitle, N'وصول چک ' + @MovementNumber, @Amount, 0);

            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            VALUES (@DocumentId, @ContraAccountId, @ContraCode, @ContraTitle, N'عکس وصول چک ' + @MovementNumber, 0, @Amount);

            -- لنگر حسابداری روی چک و حرکت نقدیِ آن (شمارهٔ مشترک Cheque:{ChequeId})
            UPDATE [treasury].[Cheques] SET DocumentId = @DocumentId WHERE ChequeId = @ChequeId;
            UPDATE [treasury].[CashMovements] SET DocumentId = @DocumentId WHERE SourceReference = CONCAT(N'Cheque:', @ChequeId);
        END
    END
END

COMMIT;
SELECT @ChequeId AS ChequeId, @ChequeNumber AS ChequeNumber, @Status AS Status;
