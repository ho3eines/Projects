-- =============================================
-- Tarazin.Data/Scripts/currency/ConvertExecute.sql
-- Schema: currency
-- Cross-schema: central, accounting, treasury
-- Execute. اجرای تبدیل ارز (PRD §39/§40/§41):
--   مبدا → ریال → مقصد؛ کارمزد (درصدی/ثابت، مبدا/مقصد/ریالی)؛
--   ثبت کیف پول هر دو ارز + گردش + سند حسابداری + تاریخچهٔ نرخ.
-- =============================================
IF @SourceAmount <= 0 OR @SourceRate <= 0 OR @TargetAmount <= 0 OR @TargetRate <= 0 OR @RialAmount <= 0
    THROW 51171, N'مقادیر تبدیل نامعتبر است', 1;
IF @SourceCurrency = @TargetCurrency
    THROW 51172, N'ارز مبدا و مقصد یکی است', 1;
-- کارمزد ریالی از صندوق/بانک دریافت می‌شود؛ کارمزد مبدا/مقصد داخل خودِ تبدیل کسر می‌شود.
IF @FeeAmount > 0 AND @FeeChargeTo = N'Rial' AND (@FundType IS NULL OR @FundType NOT IN (N'Cash', N'Bank'))
    THROW 51173, N'برای پرداخت کارمزد ریالی، صندوق یا بانک انتخاب کنید', 1;

DECLARE @SrcQty DECIMAL(18,4) = 0, @SrcAvg DECIMAL(18,2) = NULL;
SELECT @SrcQty = ISNULL(Quantity, 0), @SrcAvg = AvgBuyRate
FROM [currency].[Wallets] WHERE CurrencyCode = @SourceCurrency;

IF @SrcQty < @SourceAmount
    THROW 51174, N'موجودی ' + @SourceCurrency + N' برای تبدیل کافی نیست', 1;

-- ارزش‌گذاری بر مبنای ریال (§40): مبدا/مقصد هر دو به ریال → مابه‌التفاوت = سود/زیان تبدیل
DECLARE @TargetRialValue DECIMAL(18,2) = ROUND(@TargetAmount * @TargetRate, 0);
DECLARE @SpreadLoss DECIMAL(18,2) = ROUND(@RialAmount - @TargetRialValue - @FeeAmount, 0);
DECLARE @SrcPnl DECIMAL(18,2) = -@SpreadLoss - @FeeAmount;   -- هزینه/سود کلی تبدیل برای پای مبدا

BEGIN TRAN;
    INSERT INTO [currency].[FxTransactions]
        (TransactionNumber, TransactionDate, TransactionTime, TransactionType, Status, TotalRial, Description, CreatedBy)
    VALUES
        (N'', CAST(@RateDate AS DATE), CAST(@RateDate AS TIME(0)), N'Conversion', N'Posted', @RialAmount, @Description, @CreatedBy);

    DECLARE @TxId INT = SCOPE_IDENTITY();
    UPDATE [currency].[FxTransactions]
    SET TransactionNumber = N'FX-' + RIGHT(N'00000' + CAST(@TxId AS NVARCHAR(10)), 5)
    WHERE FxTransactionId = @TxId;

    -- خروج مبدا
    INSERT INTO [currency].[CurrencyMovements]
        (MovementNumber, MovementDate, MovementTime, MovementType, Direction, CurrencyCode, Quantity, Rate, AmountRial, FxTransactionId, SourceReference, Description, CreatedBy)
    VALUES
        (N'', CAST(@RateDate AS DATE), CAST(@RateDate AS TIME(0)), N'Conversion', N'Out', @SourceCurrency, @SourceAmount, @SourceRate, @RialAmount,
         @TxId, N'FX:' + CAST(@TxId AS NVARCHAR(20)) + N'-SRC', N'تبدیل به ' + @TargetCurrency, @CreatedBy);

    UPDATE [currency].[Wallets]
    SET Quantity = Quantity - @SourceAmount,
        OutQty = OutQty + @SourceAmount, LastMovementAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
    WHERE CurrencyCode = @SourceCurrency;

    -- ورود مقصد
    INSERT INTO [currency].[CurrencyMovements]
        (MovementNumber, MovementDate, MovementTime, MovementType, Direction, CurrencyCode, Quantity, Rate, AmountRial, FxTransactionId, SourceReference, Description, CreatedBy)
    VALUES
        (N'', CAST(@RateDate AS DATE), CAST(@RateDate AS TIME(0)), N'Conversion', N'In', @TargetCurrency, @TargetAmount, @TargetRate, @TargetRialValue,
         @TxId, N'FX:' + CAST(@TxId AS NVARCHAR(20)) + N'-DST', N'از تبدیل ' + @SourceCurrency, @CreatedBy);

    DECLARE @DstQty DECIMAL(18,4) = 0, @DstAvg DECIMAL(18,2) = NULL;
    SELECT @DstQty = ISNULL(Quantity, 0), @DstAvg = AvgBuyRate
    FROM [currency].[Wallets] WHERE CurrencyCode = @TargetCurrency;

    DECLARE @NewAvg DECIMAL(18,2);
    IF @DstAvg IS NULL OR @DstAvg = 0
        SET @NewAvg = @TargetRate;
    ELSE
        SET @NewAvg = ROUND((@DstQty * @DstAvg + @TargetAmount * @TargetRate) / (@DstQty + @TargetAmount), 0);

    IF EXISTS (SELECT 1 FROM [currency].[Wallets] WHERE CurrencyCode = @TargetCurrency)
        UPDATE [currency].[Wallets]
        SET Quantity = Quantity + @TargetAmount, AvgBuyRate = @NewAvg,
            InQty = InQty + @TargetAmount, LastMovementAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
        WHERE CurrencyCode = @TargetCurrency;
    ELSE
        INSERT INTO [currency].[Wallets] (CurrencyCode, Quantity, AvgBuyRate, OpeningQty, InQty, OutQty, UpdatedAt, UpdatedBy)
        VALUES (@TargetCurrency, @TargetAmount, @NewAvg, 0, @TargetAmount, 0, SYSUTCDATETIME(), @CreatedBy);

    -- شماره‌دهی گردش‌های ارزی این تبدیل
    UPDATE [currency].[CurrencyMovements]
    SET MovementNumber = N'CM-' + RIGHT(N'0000000' + CAST(MovementId AS NVARCHAR(20)), 7)
    WHERE FxTransactionId = @TxId AND MovementNumber = N'';

    -- پاها
    INSERT INTO [currency].[FxTransactionLegs]
        (FxTransactionId, LegType, ItemKey, Title, Direction, Quantity, Rate, AmountRial, RealizedPnl, Description)
    VALUES
        (@TxId, N'Currency', @SourceCurrency, @SourceCurrency, N'Out', @SourceAmount, @SourceRate, @RialAmount, @SrcPnl, N'تبدیل به ' + @TargetCurrency),
        (@TxId, N'Currency', @TargetCurrency, @TargetCurrency, N'In', @TargetAmount, @TargetRate, @TargetRialValue, NULL, N'از تبدیل ' + @SourceCurrency);

    -- کارمزد ریالی → خزانه (دریافت کارمزد از مشتری: صندوق/بانک افزایش می‌یابد — §41)
    IF @FeeAmount > 0 AND @FeeChargeTo = N'Rial'
    BEGIN
        INSERT INTO [treasury].[CashMovements]
            (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy)
        VALUES
            (N'', CAST(@RateDate AS DATE), N'In', @FeeAmount, N'IRR',
             CASE WHEN @FundType = N'Bank' THEN @FundId ELSE NULL END,
             CASE WHEN @FundType = N'Cash' THEN @FundId ELSE NULL END,
             N'کارمزد دریافت‌شدهٔ تبدیل ' + @SourceCurrency + N'→' + @TargetCurrency,
             N'FX:' + CAST(@TxId AS NVARCHAR(20)) + N'-FEE', N'Posted', @CreatedBy);

        IF @FundType = N'Bank'
            UPDATE [treasury].[BankAccounts]
            SET Balance = Balance + @FeeAmount WHERE AccountId = @FundId;
        ELSE
            UPDATE [treasury].[CashBoxes]
            SET Balance = Balance + @FeeAmount WHERE CashBoxId = @FundId;
    END

    -- سند حسابداری (دوبل متوازن — رجوع به منطق شرح‌شده در اسکریپت)
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1030' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'1030', N'موجودی ارز', N'Asset', 1, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6000' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'6000', N'سود و زیان تسعیر ارز', N'Income', 1, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6100' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'6100', N'کارمزد و سایر هزینه‌ها', N'Expense', 1, SYSUTCDATETIME());

    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted)
    VALUES
        (N'', CAST(@RateDate AS DATE), N'FxConvert', NULL, @RialAmount, N'IRR', N'Posted', SYSUTCDATETIME(), @CreatedBy, 0);

    DECLARE @Did INT = SCOPE_IDENTITY();
    UPDATE [accounting].[Documents]
    SET DocumentNumber = N'DOC-' + RIGHT(N'00000' + CAST(@Did AS NVARCHAR(10)), 5)
    WHERE DocumentId = @Did;

    -- بدهکار: موجودی ارز مقصد (ارزش خالص پس از کارمزد)
    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'موجودی ارز ' + @TargetCurrency, @TargetRialValue, 0
    FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'1030' AND a.IsDeleted = 0;

    -- بستانکار: موجودی ارز مبدا (ارزش کامل)
    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'موجودی ارز ' + @SourceCurrency, 0, @RialAmount
    FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'1030' AND a.IsDeleted = 0;

    -- کارمزد ریالی: از مشتری نقداً دریافت می‌شود → بدهکار صندوق/بانک (سند متوازن و هماهنگ با خزانه)
    IF @FeeAmount > 0 AND @FeeChargeTo = N'Rial'
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'دریافت کارمزد تبدیل ارز', @FeeAmount, 0
        FROM [accounting].[ChartOfAccounts] a
        WHERE a.AccountCode = CASE WHEN @FundType = N'Bank' THEN N'1010' ELSE N'1000' END AND a.IsDeleted = 0;

    -- کارمزد مبدا/مقصد: داخل خودِ تبدیل کسر شده → هزینهٔ کارمزد (سند متوازن)
    IF @FeeAmount > 0 AND @FeeChargeTo <> N'Rial'
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'کارمزد تبدیل ارز (' + @FeeChargeTo + N')', @FeeAmount, 0
        FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'6100' AND a.IsDeleted = 0;

    -- سود/زیان تبدیل (مابه‌التفاوت ریالی) → 6000
    IF @SpreadLoss <> 0
    BEGIN
        IF @SpreadLoss > 0
            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'زیان تبدیل ارز', @SpreadLoss, 0
            FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'6000' AND a.IsDeleted = 0;
        ELSE
            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'سود تبدیل ارز', 0, ABS(@SpreadLoss)
            FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'6000' AND a.IsDeleted = 0;
    END

    UPDATE [currency].[FxTransactions]
    SET DocumentId = @Did
    WHERE FxTransactionId = @TxId;

    -- تاریخچهٔ نرخ (قفل نرخ هر دو ارز — §48/§49)
    INSERT INTO [currency].[RateHistory]
        (ItemType, ItemKey, RateKind, PrevValue, NewValue, ChangeType, Reason, ChangedBy, IsOnline)
    VALUES
        (N'Currency', @SourceCurrency, N'Transaction', NULL, @SourceRate, NULL, N'Transaction', N'تبدیل ارز (' + @RateSource + N')', @CreatedBy, 0),
        (N'Currency', @TargetCurrency, N'Transaction', NULL, @TargetRate, NULL, N'Transaction', N'تبدیل ارز (' + @RateSource + N')', @CreatedBy, 0);
COMMIT;
