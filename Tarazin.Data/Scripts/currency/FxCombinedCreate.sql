-- =============================================
-- Tarazin.Data/Scripts/currency/FxCombinedCreate.sql
-- Schema: currency
-- Cross-schema: central, accounting, treasury
-- Execute. معاملات ترکیبی طلا + ارز + ریال + کالا (PRD §38):
--   «فروش طلا + دریافت دلار» / «خرید آب‌شده + پرداخت یورو» /
--   «تهاتر طلا با ارز» / «فروش دلار + دریافت بخشی ریال و بخشی طلا»
-- اثر مالی هر پای (Leg) جداگانه محاسبه و ثبت می‌شود؛ سند حسابداری باید
-- متوازن باشد (جمع ورودها = جمع خروج‌ها؛ مابه‌التفاوت به فروش/هزینه می‌رود).
--
-- LegsJson نمونه:
-- [ { "LegType":"Gold","ItemKey":"XAU-18","Direction":"Out","Quantity":10,"Rate":28000000,"AmountRial":280000000,"FundType":null,"FundId":null,"Description":"فروش طلا" },
--   { "LegType":"Currency","ItemKey":"USD","Direction":"In","Quantity":1000,"Rate":615000,"AmountRial":615000000,"FundType":"Cash","FundId":1,"Description":"دریافت دلار" } ]
-- =============================================
IF @LegsJson IS NULL OR LEN(@LegsJson) = 0
    THROW 51160, N'حداقل یک پای معامله الزامی است', 1;

DECLARE @LegCount INT, @SumIn DECIMAL(18,2) = 0, @SumOut DECIMAL(18,2) = 0, @Bad INT = 0;

SELECT @LegCount = COUNT(*),
       @SumIn  = SUM(CASE WHEN j.Direction = N'In'  THEN ISNULL(j.AmountRial, 0) ELSE 0 END),
       @SumOut = SUM(CASE WHEN j.Direction = N'Out' THEN ISNULL(j.AmountRial, 0) ELSE 0 END),
       @Bad    = SUM(CASE WHEN ISNULL(j.AmountRial, 0) <= 0 OR j.Direction NOT IN (N'In', N'Out') THEN 1 ELSE 0 END)
FROM OPENJSON(@LegsJson)
WITH (LegType NVARCHAR(20), ItemKey NVARCHAR(50), Direction NVARCHAR(10), Quantity DECIMAL(18,4), Rate DECIMAL(18,2), AmountRial DECIMAL(18,2), FundType NVARCHAR(20), FundId INT, Description NVARCHAR(300)) j;

IF @LegCount < 2
    THROW 51161, N'معاملهٔ ترکیبی حداقل دو پای دارد', 1;
IF @Bad > 0
    THROW 51162, N'یکی از پاها نامعتبر است (مبلغ یا جهت)', 1;

BEGIN TRAN;
    -- سربرگ معامله
    INSERT INTO [currency].[FxTransactions]
        (TransactionNumber, TransactionDate, TransactionTime, TransactionType, PartyName, Status, TotalRial, Description, CreatedBy)
    VALUES
        (N'', @TransactionDate, @TransactionTime, N'Combined', NULLIF(LTRIM(RTRIM(@PartyName)), N''), N'Posted', @SumIn, @Description, @CreatedBy);

    DECLARE @TxId INT = SCOPE_IDENTITY();
    UPDATE [currency].[FxTransactions]
    SET TransactionNumber = N'FX-' + RIGHT(N'00000' + CAST(@TxId AS NVARCHAR(10)), 5)
    WHERE FxTransactionId = @TxId;

    -- طرف حساب
    DECLARE @PartyId INT = NULL;
    IF LEN(LTRIM(RTRIM(@PartyName))) > 0
    BEGIN
        SELECT @PartyId = PartyId FROM [central].[Parties]
        WHERE FullName = LTRIM(RTRIM(@PartyName)) AND IsDeleted = 0;

        IF @PartyId IS NULL
        BEGIN
            INSERT INTO [central].[Parties] (PartyCode, PartyType, FullName, IsActive, CreatedAt, CreatedBy)
            VALUES (N'FX' + RIGHT(N'00000' + CAST(@TxId AS NVARCHAR(10)), 5), N'Customer', LTRIM(RTRIM(@PartyName)), 1, SYSUTCDATETIME(), @CreatedBy);
        END
    END

    -- حساب‌های ویژه (در صورت نبود)
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1030' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'1030', N'موجودی ارز', N'Asset', 1, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'1040' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'1040', N'موجودی طلا و سکه', N'Asset', 1, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'4000' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'4000', N'فروش', N'Income', 1, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM [accounting].[ChartOfAccounts] WHERE AccountCode = N'6100' AND IsDeleted = 0)
        INSERT INTO [accounting].[ChartOfAccounts] (AccountCode, Title, AccountType, IsActive, CreatedAt)
        VALUES (N'6100', N'کارمزد و سایر هزینه‌ها', N'Expense', 1, SYSUTCDATETIME());

    -- ── پردازش پاها ──────────────────────────────────────────────────
    DECLARE @LegType NVARCHAR(20), @ItemKey NVARCHAR(50), @Dir NVARCHAR(10),
            @Qty DECIMAL(18,4), @Rate DECIMAL(18,2), @Amt DECIMAL(18,2),
            @FundType NVARCHAR(20), @FundId INT, @LegDesc NVARCHAR(300);
    DECLARE @Title NVARCHAR(200), @Pnl DECIMAL(18,2), @LegSeq INT = 0;

    DECLARE legs CURSOR LOCAL FAST_FORWARD FOR
        SELECT j.LegType, j.ItemKey, j.Direction, j.Quantity, j.Rate, j.AmountRial, j.FundType, j.FundId, j.Description
        FROM OPENJSON(@LegsJson)
        WITH (LegType NVARCHAR(20), ItemKey NVARCHAR(50), Direction NVARCHAR(10), Quantity DECIMAL(18,4), Rate DECIMAL(18,2), AmountRial DECIMAL(18,2), FundType NVARCHAR(20), FundId INT, Description NVARCHAR(300)) j;

    OPEN legs;
    FETCH NEXT FROM legs INTO @LegType, @ItemKey, @Dir, @Qty, @Rate, @Amt, @FundType, @FundId, @LegDesc;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @LegSeq = @LegSeq + 1;
        SET @Pnl = 0;
        SET @FundType = NULLIF(@FundType, N'');   -- رشتهٔ خالی ← NULL (تسویه ندارد)
        SELECT TOP (1) @Title = p.Title, @Rate = ISNULL(@Rate, r.SystemRate)
        FROM [currency].[PriceItems] p
        LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
        WHERE p.ItemKey = @ItemKey AND p.IsDeleted = 0;

        IF @Title IS NULL
            THROW 51163, N'آیتم «' + @ItemKey + N'» در مرکز قیمت یافت نشد', 1;

        -- ۱) ارز → کیف پول + گردش + سود/زیان محقق‌شده
        IF @LegType = N'Currency'
        BEGIN
            DECLARE @WQty DECIMAL(18,4) = 0, @WAvg DECIMAL(18,2) = NULL;
            SELECT @WQty = ISNULL(Quantity, 0), @WAvg = AvgBuyRate
            FROM [currency].[Wallets] WHERE CurrencyCode = @ItemKey;

            IF @Dir = N'Out' AND @WQty < ISNULL(@Qty, 0)
                THROW 51164, N'موجودی ' + @ItemKey + N' برای خروج کافی نیست', 1;

            IF @Dir = N'Out' AND @WAvg IS NOT NULL AND ISNULL(@Qty, 0) > 0
                SET @Pnl = ROUND((ISNULL(@Rate, 0) - @WAvg) * @Qty, 0);

            INSERT INTO [currency].[CurrencyMovements]
                (MovementNumber, MovementDate, MovementTime, MovementType, Direction, CurrencyCode, Quantity, Rate, AmountRial,
                 CounterPartyName, FundType, FundId, FxTransactionId, SourceReference, Description, CreatedBy)
            VALUES
                (N'', @TransactionDate, @TransactionTime, N'Combined', @Dir, @ItemKey, ISNULL(@Qty, 0), ISNULL(@Rate, 0), @Amt,
                 NULLIF(LTRIM(RTRIM(@PartyName)), N''), @FundType, @FundId, @TxId,
                 N'FX:' + CAST(@TxId AS NVARCHAR(20)) + N'-' + @ItemKey + N'-' + CAST(@LegSeq AS NVARCHAR(10)), @LegDesc, @CreatedBy);

            IF @Dir = N'In'
            BEGIN
                DECLARE @NewAvg DECIMAL(18,2);
                IF @WAvg IS NULL OR @WAvg = 0
                    SET @NewAvg = @Rate;
                ELSE
                    SET @NewAvg = ROUND((@WQty * @WAvg + ISNULL(@Qty, 0) * ISNULL(@Rate, 0)) / (@WQty + ISNULL(@Qty, 0)), 0);

                IF EXISTS (SELECT 1 FROM [currency].[Wallets] WHERE CurrencyCode = @ItemKey)
                    UPDATE [currency].[Wallets]
                    SET Quantity = Quantity + ISNULL(@Qty, 0), AvgBuyRate = @NewAvg,
                        InQty = InQty + ISNULL(@Qty, 0), LastMovementAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
                    WHERE CurrencyCode = @ItemKey;
                ELSE
                    INSERT INTO [currency].[Wallets] (CurrencyCode, Quantity, AvgBuyRate, OpeningQty, InQty, OutQty, UpdatedAt, UpdatedBy)
                    VALUES (@ItemKey, ISNULL(@Qty, 0), @NewAvg, 0, ISNULL(@Qty, 0), 0, SYSUTCDATETIME(), @CreatedBy);
            END
            ELSE
                UPDATE [currency].[Wallets]
                SET Quantity = Quantity - ISNULL(@Qty, 0),
                    OutQty = OutQty + ISNULL(@Qty, 0), LastMovementAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
                WHERE CurrencyCode = @ItemKey;

            -- نرخ معامله در تاریخچه (§48/§49)
            INSERT INTO [currency].[RateHistory]
                (ItemType, ItemKey, RateKind, PrevValue, NewValue, ChangeType, Reason, ChangedBy, IsOnline)
            VALUES
                (N'Currency', @ItemKey, N'Transaction', NULL, ISNULL(@Rate, 0), NULL, N'Transaction', N'پای معاملهٔ ترکیبی', @CreatedBy, 0);
        END

        -- ۲) ریال → خزانه (صندوق/بانک)
        ELSE IF @LegType = N'Rial'
        BEGIN
            IF @FundType IS NULL
                THROW 51165, N'پای ریالی نیاز به صندوق یا بانک دارد', 1;

            INSERT INTO [treasury].[CashMovements]
                (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy)
            VALUES
                (N'', @TransactionDate, @Dir, @Amt, N'IRR',
                 CASE WHEN @FundType = N'Bank' THEN @FundId ELSE NULL END,
                 CASE WHEN @FundType = N'Cash' THEN @FundId ELSE NULL END,
                 N'پای ریالی معاملهٔ ترکیبی FX-' + RIGHT(N'00000' + CAST(@TxId AS NVARCHAR(10)), 5),
                 N'FX:' + CAST(@TxId AS NVARCHAR(20)) + N'-IRR-' + CAST(@LegSeq AS NVARCHAR(10)), N'Posted', @CreatedBy);

            IF @FundType = N'Bank'
                UPDATE [treasury].[BankAccounts]
                SET Balance = Balance + CASE WHEN @Dir = N'In' THEN @Amt ELSE -@Amt END
                WHERE AccountId = @FundId;
            ELSE
                UPDATE [treasury].[CashBoxes]
                SET Balance = Balance + CASE WHEN @Dir = N'In' THEN @Amt ELSE -@Amt END
                WHERE CashBoxId = @FundId;
        END

        -- ۳) طلا/سکه/فلز → دارایی فیزیکی (AssetHoldings)
        ELSE IF @LegType IN (N'Gold', N'Coin', N'Metal')
        BEGIN
            DECLARE @HQty DECIMAL(18,4) = 0;
            SELECT @HQty = ISNULL(Quantity, 0) FROM [currency].[AssetHoldings] WHERE ItemKey = @ItemKey;

            IF @Dir = N'Out' AND @HQty < ISNULL(@Qty, 0)
                THROW 51166, N'موجودی ' + @Title + N' برای خروج کافی نیست', 1;

            IF EXISTS (SELECT 1 FROM [currency].[AssetHoldings] WHERE ItemKey = @ItemKey)
                UPDATE [currency].[AssetHoldings]
                SET Quantity = Quantity + CASE WHEN @Dir = N'In' THEN ISNULL(@Qty, 0) ELSE -ISNULL(@Qty, 0) END,
                    CostRate = CASE WHEN @Dir = N'In' AND ISNULL(@Rate, 0) > 0 THEN @Rate ELSE CostRate END,
                    UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @CreatedBy
                WHERE ItemKey = @ItemKey;
            ELSE
                INSERT INTO [currency].[AssetHoldings] (ItemKey, Title, Quantity, CostRate, UpdatedAt, UpdatedBy)
                VALUES (@ItemKey, @Title, ISNULL(@Qty, 0), @Rate, SYSUTCDATETIME(), @CreatedBy);

            IF ISNULL(@Rate, 0) > 0
                INSERT INTO [currency].[RateHistory]
                    (ItemType, ItemKey, RateKind, PrevValue, NewValue, ChangeType, Reason, ChangedBy, IsOnline)
                VALUES
                    (@LegType, @ItemKey, N'Transaction', NULL, @Rate, NULL, N'Transaction', N'پای معاملهٔ ترکیبی', @CreatedBy, 0);
        END
        ELSE
            THROW 51167, N'نوع پای نامعتبر است', 1;

        -- ۴) ثبت پای در معامله
        INSERT INTO [currency].[FxTransactionLegs]
            (FxTransactionId, LegType, ItemKey, Title, Direction, Quantity, Rate, AmountRial, RealizedPnl, FundType, FundId, Description)
        VALUES
            (@TxId, @LegType, @ItemKey, @Title, @Dir, @Qty, @Rate, @Amt, NULLIF(@Pnl, 0), @FundType, @FundId, @LegDesc);

        FETCH NEXT FROM legs INTO @LegType, @ItemKey, @Dir, @Qty, @Rate, @Amt, @FundType, @FundId, @LegDesc;
    END
    CLOSE legs;
    DEALLOCATE legs;

    -- شماره‌دهی گردش‌های ارزی این معامله
    UPDATE [currency].[CurrencyMovements]
    SET MovementNumber = N'CM-' + RIGHT(N'0000000' + CAST(MovementId AS NVARCHAR(20)), 7)
    WHERE FxTransactionId = @TxId AND MovementNumber = N'';

    -- ── سند حسابداری متوازن ──────────────────────────────────────────
    DECLARE @Diff DECIMAL(18,2) = @SumIn - @SumOut;   -- مابه‌التفاوت (سود/زیان یا کارمزد)

    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted)
    VALUES
        (N'', @TransactionDate, N'FxCombined', NULLIF(LTRIM(RTRIM(@PartyName)), N''), @SumIn, N'IRR', N'Posted', SYSUTCDATETIME(), @CreatedBy, 0);

    DECLARE @Did INT = SCOPE_IDENTITY();
    UPDATE [accounting].[Documents]
    SET DocumentNumber = N'DOC-' + RIGHT(N'00000' + CAST(@Did AS NVARCHAR(10)), 5)
    WHERE DocumentId = @Did;

    -- ردیف‌ها از روی پاها (پای ریالی: صندوق ۱۰۰۰ یا بانک ۱۰۱۰ بر اساس تسویه)
    INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    SELECT @Did, a.AccountId, a.AccountCode, a.Title, j.Description, 
           CASE WHEN j.Direction = N'In' THEN j.AmountRial ELSE 0 END,
           CASE WHEN j.Direction = N'Out' THEN j.AmountRial ELSE 0 END
    FROM OPENJSON(@LegsJson)
    WITH (LegType NVARCHAR(20), ItemKey NVARCHAR(50), Direction NVARCHAR(10), AmountRial DECIMAL(18,2), FundType NVARCHAR(20), Description NVARCHAR(300)) j
    JOIN [currency].[PriceItems] p ON p.ItemKey = j.ItemKey
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountCode =
        CASE WHEN j.LegType = N'Currency' THEN N'1030'
             WHEN j.LegType IN (N'Gold', N'Coin', N'Metal') THEN N'1040'
             WHEN j.LegType = N'Rial' AND j.FundType = N'Bank' THEN N'1010'
             ELSE N'1000' END
        AND a.IsDeleted = 0;

    -- مابه‌التفاوت: ورود بیشتر = درآمد فروش؛ خروج بیشتر = هزینه
    IF @Diff <> 0
    BEGIN
        IF @Diff > 0
            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'سود معاملهٔ ترکیبی', 0, @Diff
            FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'4000' AND a.IsDeleted = 0;
        ELSE
            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            SELECT @Did, a.AccountId, a.AccountCode, a.Title, N'کارمزد/زیان معاملهٔ ترکیبی', ABS(@Diff), 0
            FROM [accounting].[ChartOfAccounts] a WHERE a.AccountCode = N'6100' AND a.IsDeleted = 0;
    END

    UPDATE [currency].[FxTransactions]
    SET DocumentId = @Did
    WHERE FxTransactionId = @TxId;
COMMIT;
