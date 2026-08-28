-- =============================================
-- Tarazin.Data/Scripts/treasury/CashMovementInsert.sql
-- Schema: treasury | Cross-schema: central, accounting
-- Execute. دریافت / پرداخت / انتقال.
-- پس از ثبت حرکت، اگر تنظیمات اتصال خزانه (TreasurySettings) فعال باشد،
-- سند حسابداری (Status='Note' — سند یاداشت) خودکار ساخته می‌شود (مثل طلافروشی):
--   دريافت (In) : بدهکار صندوق/بانک ← بستانکار طرف‌حساب یا حساب مقابل دریافت
--   پرداخت (Out): بستانکار صندوق/بانک ← بدهکار طرف‌حساب یا حساب مقابل پرداخت
-- =============================================
IF @Direction NOT IN (N'In', N'Out')
    THROW 51010, N'جهت نامعتبر است (In/Out)', 1;

BEGIN TRAN;
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy, CompanyId)
    VALUES
        (N'', @MovementDate, @Direction, @Amount, ISNULL(@CurrencyCode, N'IRR'), @AccountId, @CashBoxId, @Description,
         NULLIF(LTRIM(RTRIM(@SourceReference)), N''), N'Posted', @CreatedBy, @CompanyId);

    DECLARE @Mid INT = SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements]
    SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5)
    WHERE MovementId = @Mid;

    -- Keep account/cashbox balances in sync (v1: direct update).
    IF @AccountId IS NOT NULL
        UPDATE [treasury].[BankAccounts]
        SET Balance = Balance + CASE WHEN @Direction = N'In' THEN @Amount ELSE -@Amount END
        WHERE AccountId = @AccountId;

    IF @CashBoxId IS NOT NULL
        UPDATE [treasury].[CashBoxes]
        SET Balance = Balance + CASE WHEN @Direction = N'In' THEN @Amount ELSE -@Amount END
        WHERE CashBoxId = @CashBoxId;

    -- ── سند حسابداری خودکار (در صورت فعال بودن تنظیمات) ──
    DECLARE @SettingsEnabled BIT = ISNULL((SELECT IsEnabled FROM [treasury].[TreasurySettings] WHERE CompanyId = @CompanyId), 0);
    IF @SettingsEnabled = 1
    BEGIN
        IF @FiscalYearId IS NULL
            THROW 51027, N'سال مالی فعال برای ثبت سند حسابداری انتخاب نشده است.', 1;
        -- حساب صندوق/بانک از تنظیمات خزانه (کد/عنوان denormalized مثل طلافروشی)
        DECLARE @FundAccountId INT, @FundCode NVARCHAR(4000), @FundTitle NVARCHAR(200);
        IF @CashBoxId IS NOT NULL
            SELECT @FundAccountId = CashAccountId, @FundCode = CashAccountCode, @FundTitle = CashAccountTitle
            FROM [treasury].[TreasurySettings] WHERE CompanyId = @CompanyId;
        ELSE IF @AccountId IS NOT NULL
            SELECT @FundAccountId = BankChartAccountId, @FundCode = BankChartAccountCode, @FundTitle = BankChartAccountTitle
            FROM [treasury].[TreasurySettings] WHERE CompanyId = @CompanyId;

        -- طرف مقابل: تفصیلی طرف‌حساب (اگر انتخاب شده) یا حساب مقابل پیش‌فرض جهت
        DECLARE @ContraAccountId INT, @ContraCode NVARCHAR(4000), @ContraTitle NVARCHAR(200);
        IF @PartyId IS NOT NULL
        BEGIN
            SELECT @ContraAccountId = DetailLinkId, @ContraCode = DetailAccountCode,
                   @ContraTitle = p.FullName
            FROM [treasury].[PartyLinks] l
            JOIN [central].[Parties] p ON p.PartyId = l.PartyId
            WHERE l.CompanyId = @CompanyId AND l.PartyId = @PartyId;
        END
        IF @ContraAccountId IS NULL
            SELECT @ContraAccountId = CASE WHEN @Direction = N'In' THEN ReceiveContraAccountId ELSE PayContraAccountId END,
                   @ContraCode = CASE WHEN @Direction = N'In' THEN ReceiveContraAccountCode ELSE PayContraAccountCode END,
                   @ContraTitle = CASE WHEN @Direction = N'In' THEN ReceiveContraAccountTitle ELSE PayContraAccountTitle END
            FROM [treasury].[TreasurySettings] WHERE CompanyId = @CompanyId;

        IF @FundAccountId IS NULL OR @FundCode IS NULL
            THROW 51025, N'حساب صندوق/بانک در تنظیمات اتصال خزانه تنظیم نشده است.', 1;
        IF @ContraAccountId IS NULL OR @ContraCode IS NULL
            THROW 51026, N'حساب مقابل دریافت/پرداخت در تنظیمات اتصال خزانه تنظیم نشده است.', 1;

        DECLARE @MovementNumber NVARCHAR(50) = (SELECT MovementNumber FROM [treasury].[CashMovements] WHERE MovementId = @Mid);
        DECLARE @CounterParty NVARCHAR(200) = (SELECT TOP 1 FullName FROM [central].[Parties] WHERE PartyId = @PartyId AND CompanyId = @CompanyId AND IsDeleted = 0);
        DECLARE @NextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber))
                                       FROM [accounting].[Documents]
                                       WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;

        INSERT INTO [accounting].[Documents]
            (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
        VALUES
            (RIGHT(N'00000000' + CAST(@NextNum AS NVARCHAR(10)), 8), @MovementDate,
             CASE WHEN @Direction = N'In' THEN N'TreasuryIn' ELSE N'TreasuryOut' END,
             ISNULL(@CounterParty, @ContraTitle), @Amount, ISNULL(@CurrencyCode, N'IRR'),
             N'Note', @CreatedBy, 0, @CompanyId, @FiscalYearId);
        DECLARE @DocumentId INT = SCOPE_IDENTITY();

        DECLARE @FundDebit DECIMAL(18,2) = CASE WHEN @Direction = N'In' THEN @Amount ELSE 0 END;
        DECLARE @FundCredit DECIMAL(18,2) = CASE WHEN @Direction = N'Out' THEN @Amount ELSE 0 END;
        DECLARE @ContraDebit DECIMAL(18,2) = CASE WHEN @Direction = N'Out' THEN @Amount ELSE 0 END;
        DECLARE @ContraCredit DECIMAL(18,2) = CASE WHEN @Direction = N'In' THEN @Amount ELSE 0 END;

        INSERT INTO [accounting].[DocumentLines]
            (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES
            (@DocumentId, @FundAccountId, @FundCode, @FundTitle,
             CASE WHEN @Direction = N'In' THEN N'دریافت ' + @MovementNumber ELSE N'پرداخت ' + @MovementNumber END,
             @FundDebit, @FundCredit);

        INSERT INTO [accounting].[DocumentLines]
            (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES
            (@DocumentId, @ContraAccountId, @ContraCode, @ContraTitle,
             CASE WHEN @Direction = N'In' THEN N'عکس دریافت ' + @MovementNumber ELSE N'عکس پرداخت ' + @MovementNumber END,
             @ContraDebit, @ContraCredit);
    END
COMMIT;
