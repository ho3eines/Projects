-- =============================================
-- Tarazin.Data/Scripts/currency/FxTransactionCreate.sql
-- Schema: currency
-- Cross-schema: central, accounting, treasury
-- Execute. خرید/فروش ارز (PRD §37) — یک عملیات تراکنشی که هم‌زمان:
--   ۱. موجودی کیف پول ارز را تغییر می‌دهد (خرید: افزایش / فروش: کاهش)
--   ۲. گردش ارز ثبت می‌کند (نرخ معامله قفل می‌شود — §48)
--   ۳. سند حسابداری دوبل می‌سازد (موجودی ارز ↔ صندوق/بانک + سود/زیان تسعیر)
--   ۴. سمت ریالی را در خزانه (صندوق/بانک) ثبت می‌کند
--   ۵. طرف حساب را در اشخاص (central) به‌روزرسانی می‌کند
--   ۶. نرخ معامله را در تاریخچهٔ نرخ ثبت می‌کند
-- =============================================
IF @TransactionType NOT IN (N'Buy', N'Sell')
    THROW 51150, N'نوع معامله باید Buy یا Sell باشد', 1;
IF @Quantity <= 0 OR @Rate <= 0 OR @AmountRial <= 0
    THROW 51151, N'مقدار، نرخ و معادل ریالی باید بزرگ‌تر از صفر باشد', 1;
-- کنترل اشتباه ریال/تومان (§35): ریال و تومان واحدهای پایه/نمایشی‌اند و
-- در کیف پول معاملات ارزی وارد نمی‌شوند (تسویهٔ ریالی از صندوق/بانک انجام می‌شود).
IF @CurrencyCode IN (N'IRR', N'TOMAN')
    THROW 51156, N'خرید/فروش ارز فقط برای ارزهای خارجی است؛ ریال و تومان واحد پایهٔ سیستم‌اند (§35)', 1;
IF @FundType IS NOT NULL AND @FundType NOT IN (N'Cash', N'Bank')
    THROW 51152, N'نحوهٔ تسویه نامعتبر است (صندوق/بانک)', 1;

DECLARE @ItemId INT, @ItemTitle NVARCHAR(200), @SysRate DECIMAL(18,2);
SELECT TOP (1) @ItemId = p.PriceItemId, @ItemTitle = p.Title, @SysRate = r.SystemRate
FROM [currency].[PriceItems] p
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
WHERE p.ItemKey = @CurrencyCode AND p.ItemType = N'Currency' AND p.IsDeleted = 0;

IF @ItemId IS NULL
    THROW 51153, N'ارز یافت نشد — ابتدا در امکانات تعریف کنید', 1;
IF ISNULL(@SysRate, 0) <= 0
    THROW 51154, N'برای این ارز نرخ سیستمی معتبری ثبت نشده است', 1;

DECLARE @WQty DECIMAL(18,4) = 0, @WAvg DECIMAL(18,2) = NULL;
SELECT @WQty = ISNULL(Quantity, 0), @WAvg = AvgBuyRate
FROM [currency].[Wallets]
WHERE CurrencyCode = @CurrencyCode
  AND CompanyId = [central].[fn_MobileCompanyId]();

IF @TransactionType = N'Sell' AND @WQty < @Quantity
    THROW 51155, N'موجودی ارز برای فروش کافی نیست', 1;

-- سود/زیان محقق‌شدهٔ فروش = (نرخ فروش − نرخ متوسط خرید) × مقدار (§52)
DECLARE @Pnl DECIMAL(18,2) = 0;
IF @TransactionType = N'Sell' AND @WAvg IS NOT NULL
    SET @Pnl = ROUND((@Rate - @WAvg) * @Quantity, 0);

BEGIN TRAN;
    -- ۱) سربرگ معامله
    INSERT INTO [currency].[FxTransactions]
        (TransactionNumber, TransactionDate, TransactionTime, TransactionType, PartyName, Status, TotalRial, Description, CreatedBy, CompanyId)
    VALUES
        (N'', @TransactionDate, @TransactionTime, @TransactionType, NULLIF(LTRIM(RTRIM(@PartyName)), N''), N'Posted', @AmountRial, @Description, @CreatedBy, [central].[fn_MobileCompanyId]());

    DECLARE @TxId INT = SCOPE_IDENTITY();
    UPDATE [currency].[FxTransactions]
    SET TransactionNumber = N'FX-' + RIGHT(N'00000' + CAST(@TxId AS NVARCHAR(10)), 5)
    WHERE FxTransactionId = @TxId;

    -- ۲) طرف حساب (central) — upsert بر اساس نام
    DECLARE @PartyId INT = NULL;
    IF LEN(LTRIM(RTRIM(@PartyName))) > 0
    BEGIN
        SELECT @PartyId = PartyId FROM [central].[Parties]
        WHERE FullName = LTRIM(RTRIM(@PartyName))
          AND IsDeleted = 0
          AND CompanyId = [central].[fn_MobileCompanyId]();

        IF @PartyId IS NULL
        BEGIN
            INSERT INTO [central].[Parties]
                (PartyCode, PartyType, FullName, IsActive, CreatedAt, CreatedBy, CompanyId)
            VALUES
                (N'FX' + RIGHT(N'00000' + CAST(@TxId AS NVARCHAR(10)), 5),
                 CASE WHEN @TransactionType = N'Buy' THEN N'Vendor' ELSE N'Customer' END,
                 LTRIM(RTRIM(@PartyName)), 1, SYSUTCDATETIME(), @CreatedBy, [central].[fn_MobileCompanyId]());
            SET @PartyId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [central].[Parties]
            SET UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
            WHERE PartyId = @PartyId;
        END
    END

    -- ۳) گردش ارز (نرخ قفل‌شده)
    DECLARE @Direction NVARCHAR(10) = CASE WHEN @TransactionType = N'Buy' THEN N'In' ELSE N'Out' END;
    INSERT INTO [currency].[CurrencyMovements]
        (MovementNumber, MovementDate, MovementTime, MovementType, Direction, CurrencyCode, Quantity, Rate, AmountRial,
         CounterPartyName, FundType, FundId, FxTransactionId, SourceReference, Description, CreatedBy, CompanyId)
    VALUES
        (N'', @TransactionDate, @TransactionTime, @TransactionType, @Direction, @CurrencyCode, @Quantity, @Rate, @AmountRial,
         NULLIF(LTRIM(RTRIM(@PartyName)), N''), @FundType, @FundId, @TxId, N'FX:' + CAST(@TxId AS NVARCHAR(20)), @Description, @CreatedBy, [central].[fn_MobileCompanyId]());

    DECLARE @Mid BIGINT = SCOPE_IDENTITY();
    UPDATE [currency].[CurrencyMovements]
    SET MovementNumber = N'CM-' + RIGHT(N'0000000' + CAST(@Mid AS NVARCHAR(20)), 7)
    WHERE MovementId = @Mid;

    -- ۴) کیف پول
    IF @TransactionType = N'Buy'
    BEGIN
        -- نرخ متوسط خرید وزنی
        DECLARE @NewAvg DECIMAL(18,2);
        IF @WAvg IS NULL OR @WAvg = 0
            SET @NewAvg = @Rate;
        ELSE
            SET @NewAvg = ROUND((ISNULL(@WQty, 0) * @WAvg + @Quantity * @Rate) / (ISNULL(@WQty, 0) + @Quantity), 0);

        IF EXISTS (SELECT 1 FROM [currency].[Wallets]
                   WHERE CurrencyCode = @CurrencyCode
                     AND CompanyId = [central].[fn_MobileCompanyId]())
            UPDATE [currency].[Wallets]
            SET Quantity = Quantity + @Quantity, AvgBuyRate = @NewAvg,
                InQty = InQty + @Quantity, LastMovementAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
            WHERE CurrencyCode = @CurrencyCode
              AND CompanyId = [central].[fn_MobileCompanyId]();
        ELSE
            INSERT INTO [currency].[Wallets]
                (CurrencyCode, Quantity, AvgBuyRate, OpeningQty, OpeningAvgRate, InQty, OutQty, UpdatedAt, UpdatedBy, CompanyId)
            VALUES (@CurrencyCode, @Quantity, @NewAvg, 0, NULL, @Quantity, 0, SYSUTCDATETIME(), @CreatedBy, [central].[fn_MobileCompanyId]());
    END
    ELSE
    BEGIN
        UPDATE [currency].[Wallets]
        SET Quantity = Quantity - @Quantity,
            OutQty = OutQty + @Quantity, LastMovementAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
        WHERE CurrencyCode = @CurrencyCode
          AND CompanyId = [central].[fn_MobileCompanyId]();
    END

    -- ۵) سمت ریالی خزانه (صندوق/بانک) — دریافت/پرداخت
    IF @FundType IS NOT NULL
    BEGIN
        DECLARE @CashDirection NVARCHAR(10) = CASE WHEN @TransactionType = N'Buy' THEN N'Out' ELSE N'In' END;
        INSERT INTO [treasury].[CashMovements]
            (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy, CompanyId)
        VALUES
            (N'', @TransactionDate, @CashDirection, @AmountRial, N'IRR',
             CASE WHEN @FundType = N'Bank' THEN @FundId ELSE NULL END,
             CASE WHEN @FundType = N'Cash' THEN @FundId ELSE NULL END,
             N'معاملهٔ ارز ' + @CurrencyCode + N' (' + @TransactionType + N')',
             N'FX:' + CAST(@TxId AS NVARCHAR(20)), N'Posted', @CreatedBy, [central].[fn_MobileCompanyId]());

        IF @FundType = N'Bank'
            UPDATE [treasury].[BankAccounts]
            SET Balance = Balance + CASE WHEN @CashDirection = N'In' THEN @AmountRial ELSE -@AmountRial END
            WHERE AccountId = @FundId
              AND CompanyId = [central].[fn_MobileCompanyId]();
        ELSE
            UPDATE [treasury].[CashBoxes]
            SET Balance = Balance + CASE WHEN @CashDirection = N'In' THEN @AmountRial ELSE -@AmountRial END
            WHERE CashBoxId = @FundId
              AND CompanyId = [central].[fn_MobileCompanyId]();
    END

    -- ۶) سند حسابداری (دوبل) — حساب‌های ویژه در صورت نبود ساخته می‌شوند
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1030' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'1030', N'موجودی ارز', N'Asset', 1, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6000' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'6000', N'سود و زیان تسعیر ارز', N'Income', 1, SYSUTCDATETIME());

    DECLARE @FundAccount NVARCHAR(30) = CASE
        WHEN @FundType = N'Bank' THEN N'1010'
        WHEN @FundType = N'Cash' THEN N'1000'
        ELSE N'2000' END;

    DECLARE @Cost DECIMAL(18,2) = CASE WHEN @TransactionType = N'Sell' THEN ROUND(ISNULL(@WAvg, @Rate) * @Quantity, 0) ELSE @AmountRial END;

    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId)
    VALUES
        (N'', @TransactionDate, CASE WHEN @TransactionType = N'Buy' THEN N'FxBuy' ELSE N'FxSell' END,
         NULLIF(LTRIM(RTRIM(@PartyName)), N''), @AmountRial, N'IRR', N'Posted', SYSUTCDATETIME(), @CreatedBy, 0, [central].[fn_MobileCompanyId]());

    DECLARE @Did INT = SCOPE_IDENTITY();
    UPDATE [accounting].[Documents]
    SET DocumentNumber = N'DOC-' + RIGHT(N'00000' + CAST(@Did AS NVARCHAR(10)), 5)
    WHERE DocumentId = @Did;

    -- خرید: بدهکار موجودی ارز / بستانکار صندوق-بانک-پرداختنی
    -- فروش: بدهکار صندوق-بانک / بستانکار موجودی ارز (بها) + سود/زیان تسعیر
    IF @TransactionType = N'Buy'
    BEGIN
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'خرید ' + @CurrencyCode + N' — ' + CAST(@Quantity AS NVARCHAR(20)) + N' واحد', @AmountRial, 0
        FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'1030' AND a.IsDeleted = 0 AND a.CompanyId = [central].[fn_MobileCompanyId]();

        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'پرداخت بابت خرید ارز', 0, @AmountRial
        FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = @FundAccount AND a.IsDeleted = 0 AND a.CompanyId = [central].[fn_MobileCompanyId]();
    END
    ELSE
    BEGIN
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'دریافت بابت فروش ارز', @AmountRial, 0
        FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = @FundAccount AND a.IsDeleted = 0 AND a.CompanyId = [central].[fn_MobileCompanyId]();

        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'بهای تمام‌شدهٔ ارز فروخته‌شده', 0, @Cost
        FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'1030' AND a.IsDeleted = 0 AND a.CompanyId = [central].[fn_MobileCompanyId]();

        IF @Pnl <> 0
        BEGIN
            -- سود → بستانکار؛ زیان → بدهکار
            IF @Pnl > 0
                INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'سود حاصل از فروش ارز', 0, @Pnl
                FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'6000' AND a.IsDeleted = 0 AND a.CompanyId = [central].[fn_MobileCompanyId]();
            ELSE
                INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'زیان حاصل از فروش ارز', ABS(@Pnl), 0
                FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'6000' AND a.IsDeleted = 0 AND a.CompanyId = [central].[fn_MobileCompanyId]();
        END
    END

    UPDATE [currency].[FxTransactions]
    SET DocumentId = @Did
    WHERE FxTransactionId = @TxId;

    -- ۷) تاریخچهٔ نرخ — قفل نرخ معامله (§48/§49)
    INSERT INTO [currency].[RateHistory]
        (ItemType, ItemKey, RateKind, PrevValue, NewValue, SourceKey, ChangeType, Reason, ChangedBy, IsOnline)
    VALUES
        (N'Currency', @CurrencyCode, N'Transaction', @SysRate, @Rate, NULL, N'Transaction',
         N'ثبت معاملهٔ ' + @TransactionType + N' — ' + @CurrencyCode, @CreatedBy, 0);
COMMIT;
