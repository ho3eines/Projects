-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldInvoiceCreate.sql
-- Schema: goldshop
-- Execute. فاکتور فروش — چندردیفه (طلا + ارز) با تسویهٔ ترکیبی.
--   @LinesJson (JSON): ردیف‌های فاکتور — هر ردیف Gold یا Currency:
--     Gold:     {RowType:'Gold',ItemCode,Title,Qty,Price,Workmanship,Profit,TaxEnabled}
--     Currency: {RowType:'Currency',CurrencyCode,Title,Qty,Rate,TaxEnabled}
--     نرخ ارز: اگر Rate < 100 → درصد بالاتر از نرخ سیستم؛ وگرنه نرخ مستقیم (مبلغ).
--   تسویه: نقدی (@PayCash) + بانک (@PayBank) + چک (@ChequeNumber/@ChequeAmount)
--          + ارز (@PayCurrencyCode/Qty/Rate) + طلا (@PayGoldGram) + نسیه = باقیمانده.
--   الزام تراز صفر: مجموع پرداخت‌ها نباید از کل فاکتور بیشتر شود؛ نسیه همیشه
--   باقیمانده را پوشش می‌دهد.
--   پس از ثبت در یک تراکنش: دفتر طرف‌حساب (ریالی/طلا/ارز)، ردیف‌های فاکتور،
--   انبار، کیف پول ارز، خزانه (صندوق/بانک) و سند حسابداری با Status='Note'
--   (سند یاداشت) هماهنگ می‌شوند.
-- =============================================
DECLARE @TaxPct DECIMAL(9,4)=ISNULL((SELECT DefaultTaxPercent FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId),10);
DECLARE @LaborTaxPct DECIMAL(9,4)=ISNULL((SELECT LaborTaxPercent FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId),@TaxPct);

-- ── پارس ردیف‌ها و محاسبهٔ ارزش ────────────────
DECLARE @Lines TABLE (RowId INT IDENTITY PRIMARY KEY,RowType NVARCHAR(20),ItemCode NVARCHAR(50),Title NVARCHAR(200),Qty DECIMAL(18,4),Price DECIMAL(18,2),Workmanship DECIMAL(18,2),Profit DECIMAL(18,2),TaxEnabled BIT,CurrencyCode NVARCHAR(10),Rate DECIMAL(18,4),SystemRate DECIMAL(24,6),ResolvedRate DECIMAL(24,6),LineBase DECIMAL(18,2),LineTax DECIMAL(18,2),LineTotal DECIMAL(18,2));
INSERT INTO @Lines(RowType,ItemCode,Title,Qty,Price,Workmanship,Profit,TaxEnabled,CurrencyCode,Rate)
SELECT RowType,ItemCode,Title,Qty,Price,ISNULL(Workmanship,0),ISNULL(Profit,0),TaxEnabled,CurrencyCode,Rate
FROM OPENJSON(@LinesJson) WITH (
    RowType NVARCHAR(20) '$.RowType',
    ItemCode NVARCHAR(50) '$.ItemCode',
    Title NVARCHAR(200) '$.Title',
    Qty DECIMAL(18,4) '$.Qty',
    Price DECIMAL(18,2) '$.Price',
    Workmanship DECIMAL(18,2) '$.Workmanship',
    Profit DECIMAL(18,2) '$.Profit',
    TaxEnabled BIT '$.TaxEnabled',
    CurrencyCode NVARCHAR(10) '$.CurrencyCode',
    Rate DECIMAL(18,4) '$.Rate'
);
IF NOT EXISTS (SELECT 1 FROM @Lines) THROW 51084, N'حداقل یک ردیف فاکتور لازم است.', 1;
IF EXISTS (SELECT 1 FROM @Lines WHERE Qty<=0) THROW 51086, N'مقدار همهٔ ردیف‌ها باید بیشتر از صفر باشد.', 1;

UPDATE L SET SystemRate=ISNULL(r.SystemRate,0)
FROM @Lines L
LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId=(SELECT TOP 1 PriceItemId FROM [currency].[PriceItems] WHERE ItemKey=L.CurrencyCode AND IsDeleted=0)
WHERE L.RowType=N'Currency';
UPDATE @Lines SET ResolvedRate=CASE
    WHEN RowType=N'Currency' AND Rate<100 THEN ROUND(SystemRate*(1+Rate/100.0),0)
    WHEN RowType=N'Currency' THEN Rate ELSE 0 END;
IF EXISTS (SELECT 1 FROM @Lines WHERE RowType=N'Currency' AND (ResolvedRate<=0 OR Rate<=0)) THROW 51087, N'نرخ ردیف ارز باید بیشتر از صفر باشد.', 1;
IF EXISTS (SELECT 1 FROM @Lines WHERE RowType=N'Gold' AND (Price<=0 OR ItemCode IS NULL)) THROW 51088, N'جنس و قیمت ردیف طلا معتبر نیست.', 1;

UPDATE @Lines SET LineBase=CASE WHEN RowType=N'Gold' THEN ROUND(Qty*Price+Workmanship+Profit,0) ELSE ROUND(Qty*ResolvedRate,0) END;
UPDATE @Lines SET LineTax=CASE
    WHEN TaxEnabled=1 AND RowType=N'Gold' THEN ROUND((Qty*Price+Profit)*@TaxPct/100.0+Workmanship*@LaborTaxPct/100.0,0)
    WHEN TaxEnabled=1 AND RowType=N'Currency' THEN ROUND(Qty*ResolvedRate*@TaxPct/100.0,0)
    ELSE 0 END;
UPDATE @Lines SET LineTotal=LineBase+LineTax;

DECLARE @TotalBase DECIMAL(18,2)=(SELECT SUM(LineBase) FROM @Lines);
DECLARE @TotalTax DECIMAL(18,2)=(SELECT SUM(LineTax) FROM @Lines);
DECLARE @Total DECIMAL(18,2)=@TotalBase+@TotalTax;
DECLARE @GoldQty DECIMAL(18,4)=ISNULL((SELECT SUM(Qty) FROM @Lines WHERE RowType=N'Gold'),0);
DECLARE @GoldPrice DECIMAL(18,2)=CASE WHEN @GoldQty>0 THEN ROUND((SELECT SUM(Qty*Price)/@GoldQty FROM @Lines WHERE RowType=N'Gold'),0) ELSE 0 END;
DECLARE @FxRowQty DECIMAL(18,4)=ISNULL((SELECT SUM(Qty) FROM @Lines WHERE RowType=N'Currency'),0);
DECLARE @FxRowCode NVARCHAR(10)=(SELECT TOP 1 CurrencyCode FROM @Lines WHERE RowType=N'Currency');
DECLARE @GoldWorkmanship DECIMAL(18,2)=ISNULL((SELECT SUM(Workmanship) FROM @Lines WHERE RowType=N'Gold'),0);
DECLARE @GoldProfit DECIMAL(18,2)=ISNULL((SELECT SUM(Profit) FROM @Lines WHERE RowType=N'Gold'),0);

-- ── تسویه ────────────────────────────────────
DECLARE @PayCurrencyValue DECIMAL(18,2)=CASE WHEN ISNULL(@PayCurrencyQty,0)>0 THEN ROUND(ISNULL(@PayCurrencyQty,0)*ISNULL(@PayCurrencyRate,0),0) ELSE 0 END;
DECLARE @GoldTradeValue DECIMAL(18,2)=CASE WHEN ISNULL(@PayGoldGram,0)>0 THEN ROUND(ISNULL(@PayGoldGram,0)*@GoldPrice,0) ELSE 0 END;
DECLARE @ChequeAmt DECIMAL(18,2)=ISNULL(@ChequeAmount,0);
DECLARE @Payments DECIMAL(18,2)=ISNULL(@PayCash,0)+ISNULL(@PayBank,0)+@PayCurrencyValue+@GoldTradeValue+@ChequeAmt;
DECLARE @Remainder DECIMAL(18,2)=@Total-@Payments;
IF @Remainder < -0.5 THROW 51085, N'مبلغ تسویه (نقدی+بانک+چک+ارز+طلا) از کل فاکتور بیشتر است.', 1;
IF ISNULL(@PayGoldGram,0)>0 AND @GoldQty<=0 THROW 51089, N'تسویه با طلا نیاز به حداقل یک ردیف طلا در فاکتور دارد.', 1;
IF ISNULL(@PayCurrencyQty,0)>0 AND (ISNULL(@PayCurrencyCode,N'') IN (N'',N'IRR',N'TOMAN') OR ISNULL(@PayCurrencyRate,0)<=0) THROW 51090, N'ارز و نرخ پرداخت معتبر نیست.', 1;

DECLARE @CustomerName NVARCHAR(200)=(SELECT FullName FROM [central].[Parties] WHERE PartyId=@PartyId AND CompanyId=@CompanyId AND PartyType=N'Customer' AND IsDeleted=0);
IF @CustomerName IS NULL THROW 51073, N'مشتری معتبر یافت نشد.', 1;
DECLARE @WarehouseId INT=(SELECT InventoryWarehouseId FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId);

BEGIN TRAN;

-- ── کنترل موجودی انبار برای هر ردیف طلا ──────
IF @WarehouseId IS NULL THROW 51091, N'انبار پیش‌فرض طلافروشی در تنظیمات شرکت تنظیم نشده است.', 1;
DECLARE @GL NVARCHAR(50),@GLQty DECIMAL(18,4),@GLPrice DECIMAL(18,2),@GLCode NVARCHAR(50);
DECLARE curGold CURSOR LOCAL FAST_FORWARD FOR SELECT ItemCode,Qty,Price FROM @Lines WHERE RowType=N'Gold';
OPEN curGold;
FETCH NEXT FROM curGold INTO @GL,@GLQty,@GLPrice;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @GLCode=InventoryItemCode FROM [goldshop].[GoldItems] WHERE ItemCode=@GL AND CompanyId=@CompanyId AND IsDeleted=0;
    SET @GLCode=COALESCE(@GLCode,REPLACE(@GL,N'XAU-',N'GOLD-'));
    IF NOT EXISTS (SELECT 1 FROM [inventory].[Items] WHERE CompanyId=@CompanyId AND ItemCode=@GLCode AND IsDeleted=0)
    BEGIN DECLARE @NoItemMsg NVARCHAR(2048)=N'کالای انبار ' + ISNULL(@GLCode,N'') + N' برای فروش موجود نیست.'; THROW 51092, @NoItemMsg, 1; END
    IF (SELECT StockQty FROM [inventory].[Items] WHERE CompanyId=@CompanyId AND ItemCode=@GLCode AND IsDeleted=0) < @GLQty
    BEGIN DECLARE @LowStockMsg NVARCHAR(2048)=N'موجودی انبار برای فروش ' + ISNULL(@GL,N'') + N' کافی نیست.'; THROW 51075, @LowStockMsg, 1; END
    FETCH NEXT FROM curGold INTO @GL,@GLQty,@GLPrice;
END
CLOSE curGold; DEALLOCATE curGold;

-- ── کنترل کیف پول ارز برای ردیف‌های ارز ───────
DECLARE @FXC NVARCHAR(10),@FXQ DECIMAL(18,4),@FXR DECIMAL(18,4);
DECLARE curFx CURSOR LOCAL FAST_FORWARD FOR SELECT CurrencyCode,Qty,ResolvedRate FROM @Lines WHERE RowType=N'Currency';
OPEN curFx;
FETCH NEXT FROM curFx INTO @FXC,@FXQ,@FXR;
WHILE @@FETCH_STATUS=0
BEGIN
    IF @FXC IN (N'IRR',N'TOMAN') THROW 51077, N'برای ردیف ارز فقط ارز خارجی مجاز است.', 1;
    IF NOT EXISTS (SELECT 1 FROM [currency].[Wallets] WHERE CurrencyCode=@FXC AND CompanyId=@CompanyId)
    BEGIN DECLARE @NoWalletMsg NVARCHAR(2048)=N'کیف پول ' + ISNULL(@FXC,N'') + N' برای شرکت فعال تعریف نشده است.'; THROW 51078, @NoWalletMsg, 1; END
    IF (SELECT Quantity FROM [currency].[Wallets] WHERE CurrencyCode=@FXC AND CompanyId=@CompanyId) < @FXQ
    BEGIN DECLARE @LowWalletMsg NVARCHAR(2048)=N'موجودی کیف پول ' + ISNULL(@FXC,N'') + N' برای فروش کافی نیست.'; THROW 51079, @LowWalletMsg, 1; END
    FETCH NEXT FROM curFx INTO @FXC,@FXQ,@FXR;
END
CLOSE curFx; DEALLOCATE curFx;

-- ── سرصفحه فاکتور ────────────────────────────
INSERT INTO [goldshop].[SaleInvoices]
    (InvoiceNumber,InvoiceDate,CustomerName,PartyId,ItemCode,WeightGram,Workmanship,Profit,Tax,TotalAmount,Status,CurrencyCode,PaymentStatus,CreatedAt,CreatedBy,CompanyId)
VALUES (N'',@InvoiceDate,@CustomerName,@PartyId,ISNULL((SELECT TOP 1 ItemCode FROM @Lines WHERE RowType=N'Gold'),N'CURRENCY'),
        @GoldQty,@GoldWorkmanship,@GoldProfit,@TotalTax,@Total,N'Issued',N'IRR',
        CASE WHEN @Remainder<=0 THEN N'Paid' WHEN @Payments>0 THEN N'Partial' ELSE N'Unpaid' END,
        SYSUTCDATETIME(),@CreatedBy,@CompanyId);
DECLARE @InvoiceId INT=SCOPE_IDENTITY();
DECLARE @InvoiceNumber NVARCHAR(50)=N'GINV-'+RIGHT(N'00000'+CAST(@InvoiceId AS NVARCHAR(10)),5);
UPDATE [goldshop].[SaleInvoices] SET InvoiceNumber=@InvoiceNumber WHERE InvoiceId=@InvoiceId;

-- ── ردیف‌های فاکتور ──────────────────────────
INSERT INTO [goldshop].[InvoiceLines](CompanyId,InvoiceId,RowType,ItemCode,Title,Qty,Price,Rate,Workmanship,Profit,TaxEnabled,LineBase,LineTax,LineTotal)
SELECT @CompanyId,@InvoiceId,RowType,ItemCode,Title,Qty,ISNULL(Price,0),CASE WHEN RowType=N'Currency' THEN ResolvedRate ELSE NULL END,Workmanship,Profit,TaxEnabled,LineBase,LineTax,LineTotal
FROM @Lines ORDER BY RowId;

-- ── دفتر طرف‌حساب (بدهکار ریالی/طلا/ارز) ─────
INSERT INTO [goldshop].[GoldPartyLedger]
    (CompanyId,PartyId,InvoiceId,EntryDate,EntryType,DebitRial,CreditRial,DebitGoldGram,CreditGoldGram,DebitCurrency,CreditCurrency,CurrencyCode,CreatedBy,Description)
VALUES (@CompanyId,@PartyId,@InvoiceId,@InvoiceDate,N'Sale',@Total,@Payments,@GoldQty,ISNULL(@PayGoldGram,0),
        @FxRowQty,ISNULL(@PayCurrencyQty,0),COALESCE(@FxRowCode,@PayCurrencyCode),@CreatedBy,
        N'فروش ' + @InvoiceNumber + CASE WHEN @FxRowQty>0 THEN N' + ارز '+@FxRowCode ELSE N'' END
        + CASE WHEN @Remainder>0 THEN N'؛ نسیه: ' + FORMAT(@Remainder,N'#,##0') + N' ریال' + CASE WHEN @CreditType=N'Gold' THEN N' (بصورت طلا)' ELSE N'' END ELSE N'' END);

-- ── خروج طلا از انبار (هر ردیف طلا) ───────────
DECLARE curGold2 CURSOR LOCAL FAST_FORWARD FOR SELECT ItemCode,Qty,Price FROM @Lines WHERE RowType=N'Gold';
OPEN curGold2;
FETCH NEXT FROM curGold2 INTO @GL,@GLQty,@GLPrice;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @GLCode=InventoryItemCode FROM [goldshop].[GoldItems] WHERE ItemCode=@GL AND CompanyId=@CompanyId AND IsDeleted=0;
    SET @GLCode=COALESCE(@GLCode,REPLACE(@GL,N'XAU-',N'GOLD-'));
    DECLARE @InvItemId INT=(SELECT ItemId FROM [inventory].[Items] WHERE CompanyId=@CompanyId AND ItemCode=@GLCode AND IsDeleted=0);
    INSERT INTO [inventory].[Movements]
        (MovementNumber,MovementType,ItemId,WarehouseId,Qty,UnitPrice,MovementDate,Description,Status,CreatedBy,CompanyId)
    VALUES (N'',N'Issue',@InvItemId,@WarehouseId,@GLQty,@GLPrice,@InvoiceDate,N'حواله بابت '+@InvoiceNumber,N'Posted',@CreatedBy,@CompanyId);
    DECLARE @MvId INT=SCOPE_IDENTITY();
    UPDATE [inventory].[Movements] SET MovementNumber=N'MV-'+RIGHT(N'00000'+CAST(@MvId AS NVARCHAR(10)),5) WHERE MovementId=@MvId;
    UPDATE [inventory].[Items] SET StockQty=StockQty-@GLQty,UpdatedAt=SYSUTCDATETIME() WHERE ItemId=@InvItemId AND CompanyId=@CompanyId;
    FETCH NEXT FROM curGold2 INTO @GL,@GLQty,@GLPrice;
END
CLOSE curGold2; DEALLOCATE curGold2;

-- ── ورود طلای تحویلی (تسویه با طلا) ──────────
IF ISNULL(@PayGoldGram,0)>0
BEGIN
    DECLARE @GLCode2 NVARCHAR(50)=(SELECT TOP 1 COALESCE((SELECT InventoryItemCode FROM [goldshop].[GoldItems] g WHERE g.ItemCode=l.ItemCode AND g.CompanyId=@CompanyId AND g.IsDeleted=0),REPLACE(l.ItemCode,N'XAU-',N'GOLD-')) FROM @Lines l WHERE l.RowType=N'Gold');
    DECLARE @InvItemId2 INT=(SELECT ItemId FROM [inventory].[Items] WHERE CompanyId=@CompanyId AND ItemCode=@GLCode2 AND IsDeleted=0);
    INSERT INTO [inventory].[Movements]
        (MovementNumber,MovementType,ItemId,WarehouseId,Qty,UnitPrice,MovementDate,Description,Status,CreatedBy,CompanyId)
    VALUES (N'',N'Receipt',@InvItemId2,@WarehouseId,@PayGoldGram,@GoldPrice,@InvoiceDate,N'تحویل طلا بابت تسویه '+@InvoiceNumber,N'Posted',@CreatedBy,@CompanyId);
    DECLARE @MvId2 INT=SCOPE_IDENTITY();
    UPDATE [inventory].[Movements] SET MovementNumber=N'MV-'+RIGHT(N'00000'+CAST(@MvId2 AS NVARCHAR(10)),5) WHERE MovementId=@MvId2;
    UPDATE [inventory].[Items] SET StockQty=StockQty+@PayGoldGram,UpdatedAt=SYSUTCDATETIME() WHERE ItemId=@InvItemId2 AND CompanyId=@CompanyId;
END

-- ── خروج ارز از کیف پول (ردیف‌های ارز) ───────
DECLARE curFx2 CURSOR LOCAL FAST_FORWARD FOR SELECT CurrencyCode,Qty,ResolvedRate FROM @Lines WHERE RowType=N'Currency';
OPEN curFx2;
FETCH NEXT FROM curFx2 INTO @FXC,@FXQ,@FXR;
WHILE @@FETCH_STATUS=0
BEGIN
    INSERT INTO [currency].[CurrencyMovements]
        (MovementNumber,MovementDate,MovementTime,MovementType,Direction,CurrencyCode,Quantity,Rate,AmountRial,CounterPartyName,SourceReference,Description,CreatedBy,CompanyId)
    VALUES (N'',@InvoiceDate,CONVERT(TIME(0),SYSUTCDATETIME()),N'Sell',N'Out',@FXC,@FXQ,@FXR,ROUND(@FXQ*@FXR,0),
            @CustomerName,CONCAT(N'GOLDINV:',@InvoiceId),N'فروش ارز بابت '+@InvoiceNumber,@CreatedBy,@CompanyId);
    UPDATE [currency].[Wallets]
    SET Quantity=Quantity-@FXQ,OutQty=OutQty+@FXQ,LastMovementAt=SYSUTCDATETIME(),UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@CreatedBy
    WHERE CurrencyCode=@FXC AND CompanyId=@CompanyId;
    FETCH NEXT FROM curFx2 INTO @FXC,@FXQ,@FXR;
END
CLOSE curFx2; DEALLOCATE curFx2;

-- ── ورود ارز پرداختی مشتری به کیف پول ────────
IF ISNULL(@PayCurrencyQty,0)>0
BEGIN
    DECLARE @PayRate DECIMAL(24,6)=CASE WHEN @PayCurrencyRate<100 THEN ROUND(ISNULL((SELECT SystemRate FROM [currency].[PriceRates] WHERE PriceItemId=(SELECT TOP 1 PriceItemId FROM [currency].[PriceItems] WHERE ItemKey=@PayCurrencyCode AND IsDeleted=0)),0)*(1+@PayCurrencyRate/100.0),0) ELSE @PayCurrencyRate END;
    DECLARE @WQ DECIMAL(18,4)=ISNULL((SELECT Quantity FROM [currency].[Wallets] WHERE CurrencyCode=@PayCurrencyCode AND CompanyId=@CompanyId),0);
    DECLARE @WA DECIMAL(18,2)=ISNULL((SELECT AvgBuyRate FROM [currency].[Wallets] WHERE CurrencyCode=@PayCurrencyCode AND CompanyId=@CompanyId),0);
    DECLARE @NAvg DECIMAL(18,2)=CASE WHEN @WQ<=0 OR @WA<=0 THEN @PayRate ELSE ROUND((@WQ*@WA+@PayCurrencyQty*@PayRate)/(@WQ+@PayCurrencyQty),0) END;
    IF EXISTS (SELECT 1 FROM [currency].[Wallets] WHERE CurrencyCode=@PayCurrencyCode AND CompanyId=@CompanyId)
        UPDATE [currency].[Wallets] SET Quantity=Quantity+@PayCurrencyQty,AvgBuyRate=@NAvg,InQty=InQty+@PayCurrencyQty,LastMovementAt=SYSUTCDATETIME(),UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@CreatedBy
        WHERE CurrencyCode=@PayCurrencyCode AND CompanyId=@CompanyId;
    ELSE
        INSERT INTO [currency].[Wallets](CurrencyCode,Quantity,AvgBuyRate,OpeningQty,InQty,OutQty,UpdatedAt,UpdatedBy,CompanyId)
        VALUES (@PayCurrencyCode,@PayCurrencyQty,@NAvg,0,@PayCurrencyQty,0,SYSUTCDATETIME(),@CreatedBy,@CompanyId);
    INSERT INTO [currency].[CurrencyMovements]
        (MovementNumber,MovementDate,MovementTime,MovementType,Direction,CurrencyCode,Quantity,Rate,AmountRial,CounterPartyName,SourceReference,Description,CreatedBy,CompanyId)
    VALUES (N'',@InvoiceDate,CONVERT(TIME(0),SYSUTCDATETIME()),N'Receive',N'In',@PayCurrencyCode,@PayCurrencyQty,@PayRate,@PayCurrencyValue,
            @CustomerName,CONCAT(N'GOLDINV:',@InvoiceId),N'دریافت ارز بابت تسویه '+@InvoiceNumber,@CreatedBy,@CompanyId);
END

-- ── خزانه: نقدی / بانک / چک (دریافت) ─────────
DECLARE @TreasuryCashBoxId INT=(SELECT CashBoxId FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId);
DECLARE @TreasuryBankId INT=(SELECT BankAccountId FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId);
IF @ChequeAmt>0
BEGIN
    IF ISNULL(@ChequeNumber,N'')='' THROW 51096, N'شماره چک الزامی است.', 1;
    IF @ChequeBankId IS NULL THROW 51097, N'بانک چک الزامی است.', 1;
    INSERT INTO [treasury].[Cheques](ChequeNumber,BankId,Amount,DueDate,Direction,Status,CreatedAt,CreatedBy,CompanyId)
    VALUES(@ChequeNumber,@ChequeBankId,@ChequeAmt,ISNULL(@ChequeDueDate,@InvoiceDate),N'In',N'Pending',SYSUTCDATETIME(),@CreatedBy,@CompanyId);
END
IF ISNULL(@PayCash,0)>0
BEGIN
    IF @TreasuryCashBoxId IS NULL THROW 51076, N'صندوق پیش‌فرض طلافروشی تنظیم نشده است.', 1;
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber,MovementDate,Direction,Amount,CurrencyCode,AccountId,CashBoxId,Description,SourceReference,Status,CreatedBy,CompanyId)
    VALUES (N'',@InvoiceDate,N'In',@PayCash,N'IRR',NULL,@TreasuryCashBoxId,N'دریافت نقدی '+@InvoiceNumber,CONCAT(N'GoldInvoice:',@InvoiceId),N'Posted',@CreatedBy,@CompanyId);
    DECLARE @CM1 INT=SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements] SET MovementNumber=N'CSH-'+RIGHT(N'00000'+CAST(@CM1 AS NVARCHAR(10)),5) WHERE MovementId=@CM1;
    UPDATE [treasury].[CashBoxes] SET Balance=Balance+@PayCash WHERE CashBoxId=@TreasuryCashBoxId AND CompanyId=@CompanyId;
END
IF ISNULL(@PayBank,0)>0
BEGIN
    IF @TreasuryBankId IS NULL THROW 51076, N'حساب بانکی پیش‌فرض طلافروشی تنظیم نشده است.', 1;
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber,MovementDate,Direction,Amount,CurrencyCode,AccountId,CashBoxId,Description,SourceReference,Status,CreatedBy,CompanyId)
    VALUES (N'',@InvoiceDate,N'In',@PayBank,N'IRR',@TreasuryBankId,NULL,N'دریافت بانکی '+@InvoiceNumber,CONCAT(N'GoldInvoice:',@InvoiceId),N'Posted',@CreatedBy,@CompanyId);
    DECLARE @CM2 INT=SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements] SET MovementNumber=N'CSH-'+RIGHT(N'00000'+CAST(@CM2 AS NVARCHAR(10)),5) WHERE MovementId=@CM2;
    UPDATE [treasury].[BankAccounts] SET Balance=Balance+@PayBank WHERE AccountId=@TreasuryBankId AND CompanyId=@CompanyId;
END

-- ── سند حسابداری (سند یاداشت — Status='Note') ─
DECLARE @PartyAccountId INT=(SELECT DetailLinkId FROM [goldshop].[GoldPartyLinks] WHERE CompanyId=@CompanyId AND PartyId=@PartyId);
DECLARE @PartyCode NVARCHAR(50)=(SELECT DetailAccountCode FROM [goldshop].[GoldPartyLinks] WHERE CompanyId=@CompanyId AND PartyId=@PartyId);
DECLARE @SalesId INT,@SalesCode NVARCHAR(4000),@SalesTitle NVARCHAR(200);
DECLARE @TaxId INT,@TaxCode NVARCHAR(4000),@TaxTitle NVARCHAR(200);
DECLARE @CashId INT,@CashCode NVARCHAR(4000),@CashTitle NVARCHAR(200);
DECLARE @BankId INT,@BankCode NVARCHAR(4000),@BankTitle NVARCHAR(200);
DECLARE @InvId INT,@InvCode NVARCHAR(4000),@InvTitle NVARCHAR(200);
SELECT @SalesId=SalesAccountId,@SalesCode=SalesAccountCode,@SalesTitle=SalesAccountTitle,
       @TaxId=TaxPayableAccountId,@TaxCode=TaxPayableAccountCode,@TaxTitle=TaxPayableAccountTitle,
       @CashId=CashAccountId,@CashCode=CashAccountCode,@CashTitle=CashAccountTitle,
       @BankId=BankChartAccountId,@BankCode=BankChartAccountCode,@BankTitle=BankChartAccountTitle,
       @InvId=InventoryAccountId,@InvCode=InventoryAccountCode,@InvTitle=InventoryAccountTitle
FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId;
-- Fallback: حساب‌های قدیمی (فقط ChartOfAccounts تخت)
IF @SalesCode IS NULL SELECT @SalesCode=a.AccountCode,@SalesTitle=a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId=@SalesId AND a.CompanyId=@CompanyId AND a.IsDeleted=0;
IF @TaxCode IS NULL AND @TaxId IS NOT NULL SELECT @TaxCode=a.AccountCode,@TaxTitle=a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId=@TaxId AND a.CompanyId=@CompanyId AND a.IsDeleted=0;
IF @CashCode IS NULL AND @CashId IS NOT NULL SELECT @CashCode=a.AccountCode,@CashTitle=a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId=@CashId AND a.CompanyId=@CompanyId AND a.IsDeleted=0;
IF @BankCode IS NULL AND @BankId IS NOT NULL SELECT @BankCode=a.AccountCode,@BankTitle=a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId=@BankId AND a.CompanyId=@CompanyId AND a.IsDeleted=0;
IF @InvCode IS NULL AND @InvId IS NOT NULL SELECT @InvCode=a.AccountCode,@InvTitle=a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId=@InvId AND a.CompanyId=@CompanyId AND a.IsDeleted=0;
IF @PartyAccountId IS NULL OR @PartyCode IS NULL OR @SalesId IS NULL OR @SalesCode IS NULL
    THROW 51093, N'لینک حسابداری مشتری یا حساب فروش در تنظیمات شرکت تنظیم نشده است.', 1;
IF @TotalTax>0 AND (@TaxId IS NULL OR @TaxCode IS NULL) THROW 51094, N'حساب مالیات در تنظیمات شرکت تنظیم نشده است.', 1;

DECLARE @NextNum INT=ISNULL((SELECT MAX(TRY_CONVERT(INT,DocumentNumber)) FROM [accounting].[Documents] WHERE CompanyId=@CompanyId AND FiscalYearId=@FiscalYearId AND IsDeleted=0),0)+1;
INSERT INTO [accounting].[Documents](DocumentNumber,DocumentDate,DocumentType,CounterPartyName,TotalAmount,CurrencyCode,Status,CreatedBy,IsDeleted,CompanyId,FiscalYearId)
VALUES(RIGHT(N'00000000'+CAST(@NextNum AS NVARCHAR(10)),8),@InvoiceDate,N'Sale',@CustomerName,@Total,N'IRR',N'Note',@CreatedBy,0,@CompanyId,@FiscalYearId);
DECLARE @DocumentId INT=SCOPE_IDENTITY();
DECLARE @CashLine DECIMAL(18,2)=ISNULL(@PayCash,0)+@PayCurrencyValue;
IF @CashLine>0 AND @CashId IS NOT NULL AND @CashCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
    VALUES(@DocumentId,@CashId,@CashCode,@CashTitle,CASE WHEN @PayCurrencyValue>0 THEN N'دریافت نقدی و ارز '+@InvoiceNumber ELSE N'دریافت نقدی '+@InvoiceNumber END,@CashLine,0);
IF ISNULL(@PayBank,0)>0 AND @BankId IS NOT NULL AND @BankCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
    VALUES(@DocumentId,@BankId,@BankCode,@BankTitle,N'دریافت بانکی '+@InvoiceNumber,@PayBank,0);
IF @GoldTradeValue>0 AND @InvId IS NOT NULL AND @InvCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
    VALUES(@DocumentId,@InvId,@InvCode,@InvTitle,N'تحویل طلا بابت تسویه '+@InvoiceNumber,@GoldTradeValue,0);
IF @ChequeAmt>0
    INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
    VALUES(@DocumentId,@BankId,@BankCode,@BankTitle,N'دریافت چک '+ISNULL(@ChequeNumber,N'')+' '+@InvoiceNumber,@ChequeAmt,0);
IF @Remainder>0
    INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
    VALUES(@DocumentId,@PartyAccountId,@PartyCode,@CustomerName,N'نسیه '+@InvoiceNumber,@Remainder,0);
INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
VALUES(@DocumentId,@SalesId,@SalesCode,@SalesTitle,CASE WHEN @FxRowQty>0 THEN N'فروش طلا و ارز '+@InvoiceNumber ELSE N'فروش طلا '+@InvoiceNumber END,0,@TotalBase);
IF @TotalTax>0 AND @TaxId IS NOT NULL AND @TaxCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId,AccountId,AccountCode,Title,Description,Debit,Credit)
    VALUES(@DocumentId,@TaxId,@TaxCode,@TaxTitle,N'مالیات '+@InvoiceNumber,0,@TotalTax);
COMMIT;
SELECT @InvoiceId AS InvoiceId,@InvoiceNumber AS InvoiceNumber,@TotalTax AS Tax,@Total AS TotalAmount,@Remainder AS BalanceRial,@DocumentId AS DocumentId;
