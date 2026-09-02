-- =============================================
-- Tarazin.Data/Scripts/store/OrderPlace.sql
-- Schema: store
-- Execute. ثبت سفارش از سبد — زنجیرهٔ یکپارچه (الگوی طلافروشی GoldInvoiceCreate):
--   1) سفارش + اقلام (سبد پاک می‌شود)
--   2) کنترل موجودی و خروج FIFO از انبار (لایه‌ها + حرکات + StockQty) + آزادسازی رزرو
--   3) دفتر مشتری (OrderLedger — بدهکار کل، بستانکار تسویه)
--   4) خزانه: دریافت نقدی / بانکی / چک (با SourceReference)
--   5) سند حسابداری (Status='Note') — بدهکار: نسیه/نقد/بانک/چک، بستانکار: فروش
--   تسویه: نقدی (@PayCash) + بانک (@PayBank) + چک (@ChequeNumber/@ChequeAmount)؛
--   باقیمانده = نسیه (بدهی مشتری در دفتر و سند). تراز صفر الزامی است.
--
-- WAVE 3 — موتور قیمت (همان منطق OrderPriceQuote):
--   ۱) ProductPrices (لیست قیمت per-store، بازهٔ تاریخ، MinQty)
--   ۲) Products.DiscountPrice (در بازه)
--   ۳) Products.Price (پایه)
--   سپس Promotion فعال (دقیق‌ترین دامنه برنده) و در پایان Coupon
--   (@CouponCode با سقف MaxDiscount و سقف مصرف). خروجی: GrossTotal −
--   DiscountTotal = TotalAmount؛ مصرف کوپن در CouponRedemptions (idempotent
--   با UX_CouponRed_Order) و UsedCount++.
-- =============================================
DECLARE @CustomerName NVARCHAR(200), @CustomerPartyId INT;
SELECT @CustomerName = cu.FullName, @CustomerPartyId = cu.PartyId
FROM [store].[Customers] cu
WHERE cu.CustomerId = @CustomerId AND cu.CompanyId = @CompanyId AND cu.IsDeleted = 0;

IF @CustomerName IS NULL
    THROW 51030, N'مشتری یافت نشد', 1;
IF @CustomerPartyId IS NULL
    THROW 51080, N'مشتری فروشگاه به طرف حساب (central.Parties) لینک نشده است؛ مشتری را دوباره ذخیره کنید.', 1;

-- ── اقلام سبد با قیمت مؤثر (موتور قیمت موج ۳) ────
DECLARE @EffDate DATE = ISNULL(@OrderDate, CAST(SYSDATETIME() AS DATE));
DECLARE @StoreEff INT = COALESCE(@StoreId,
    (SELECT StoreId FROM [store].[Customers] WHERE CustomerId = @CustomerId AND IsDeleted = 0));

DECLARE @Cart TABLE (CartItemId INT, ProductId INT, ProductCode NVARCHAR(50), Title NVARCHAR(200),
                     ItemCode NVARCHAR(50), CategoryId INT, Qty DECIMAL(18,3),
                     UnitPrice DECIMAL(18,2), LineTotal DECIMAL(18,2));
INSERT INTO @Cart (CartItemId, ProductId, ProductCode, Title, ItemCode, CategoryId, Qty, UnitPrice, LineTotal)
SELECT c.CartItemId, c.ProductId, c.ProductCode, c.Title, c.ItemCode, c.CategoryId, c.Qty, c.UnitPrice, c.LineTotal
FROM (
    SELECT ci.CartItemId, p.ProductId, p.ProductCode, p.Title, p.ItemCode, p.CategoryId, ci.Qty,
           COALESCE(
               (SELECT TOP 1 pp.Price
                  FROM [store].[ProductPrices] pp
                 WHERE pp.CompanyId = @CompanyId
                   AND pp.ProductId = p.ProductId
                   AND pp.IsDeleted = 0
                   AND (@PriceListId IS NULL OR pp.PriceListId = @PriceListId)
                   AND (@StoreEff IS NULL OR pp.StoreId IS NULL OR pp.StoreId = @StoreEff)
                   AND (pp.FromDate IS NULL OR pp.FromDate <= @EffDate)
                   AND (pp.ToDate   IS NULL OR pp.ToDate   >= @EffDate)
                   AND pp.MinQty <= ci.Qty
                 ORDER BY (CASE WHEN pp.StoreId IS NOT NULL THEN 0 ELSE 1 END), pp.MinQty DESC),
               CASE WHEN p.DiscountPrice IS NOT NULL
                     AND (p.DiscountFrom IS NULL OR p.DiscountFrom <= SYSDATETIME())
                     AND (p.DiscountTo   IS NULL OR p.DiscountTo   >= SYSDATETIME())
                    THEN p.DiscountPrice END,
               p.Price) AS UnitPrice,
           ROUND(ci.Qty * COALESCE(
               (SELECT TOP 1 pp.Price
                  FROM [store].[ProductPrices] pp
                 WHERE pp.CompanyId = @CompanyId
                   AND pp.ProductId = p.ProductId
                   AND pp.IsDeleted = 0
                   AND (@PriceListId IS NULL OR pp.PriceListId = @PriceListId)
                   AND (@StoreEff IS NULL OR pp.StoreId IS NULL OR pp.StoreId = @StoreEff)
                   AND (pp.FromDate IS NULL OR pp.FromDate <= @EffDate)
                   AND (pp.ToDate   IS NULL OR pp.ToDate   >= @EffDate)
                   AND pp.MinQty <= ci.Qty
                 ORDER BY (CASE WHEN pp.StoreId IS NOT NULL THEN 0 ELSE 1 END), pp.MinQty DESC),
               CASE WHEN p.DiscountPrice IS NOT NULL
                     AND (p.DiscountFrom IS NULL OR p.DiscountFrom <= SYSDATETIME())
                     AND (p.DiscountTo   IS NULL OR p.DiscountTo   >= SYSDATETIME())
                    THEN p.DiscountPrice END,
               p.Price), 0) AS LineTotal
    FROM [store].[CartItems] ci
    JOIN [store].[Products] p ON p.ProductId = ci.ProductId
    WHERE ci.CustomerId = @CustomerId AND ci.CompanyId = @CompanyId
) c;

IF NOT EXISTS (SELECT 1 FROM @Cart)
    THROW 51031, N'سبد خرید خالی است', 1;

DECLARE @GrossTotal DECIMAL(18,2) = (SELECT SUM(LineTotal) FROM @Cart);

-- ── Promotion فعال (دقیق‌ترین دامنه: محصول > دسته > همه) ────
DECLARE @PromoId INT = NULL, @PromoDiscount DECIMAL(18,2) = 0;
SELECT TOP 1 @PromoId = pr.PromotionId,
       @PromoDiscount = CASE pr.DiscountType
                            WHEN N'Percent' THEN ROUND(@GrossTotal * pr.DiscountValue / 100.0, 0)
                            ELSE pr.DiscountValue END
FROM [store].[Promotions] pr
WHERE pr.CompanyId = @CompanyId
  AND pr.IsActive = 1 AND pr.IsDeleted = 0
  AND GETDATE() BETWEEN pr.FromDate AND pr.ToDate
  AND @GrossTotal >= pr.MinOrderTotal
  AND (@StoreEff IS NULL OR pr.StoreId IS NULL OR pr.StoreId = @StoreEff)
  AND (   (pr.ProductId IS NOT NULL AND EXISTS (SELECT 1 FROM @Cart c WHERE c.ProductId = pr.ProductId))
       OR (pr.ProductId IS NULL AND pr.CategoryId IS NOT NULL
           AND EXISTS (SELECT 1 FROM @Cart c WHERE c.CategoryId = pr.CategoryId))
       OR (pr.ProductId IS NULL AND pr.CategoryId IS NULL) )
ORDER BY CASE WHEN pr.ProductId IS NOT NULL THEN 0
              WHEN pr.CategoryId IS NOT NULL THEN 1
              ELSE 2 END;

-- ── Coupon (@CouponCode اختیاری) ────────────────────────────
DECLARE @CouponId INT = NULL, @CouponDiscount DECIMAL(18,2) = 0;
IF @CouponCode IS NOT NULL AND LTRIM(RTRIM(@CouponCode)) <> N''
BEGIN
    DECLARE @CouponType NVARCHAR(10), @CouponValue DECIMAL(18,2), @CouponMax DECIMAL(18,2);
    SELECT @CouponId = cp.CouponId, @CouponType = cp.DiscountType, @CouponValue = cp.DiscountValue,
           @CouponMax = cp.MaxDiscount
    FROM [store].[Coupons] cp
    WHERE cp.CompanyId = @CompanyId AND cp.Code = @CouponCode AND cp.IsDeleted = 0
      AND cp.IsActive = 1
      AND GETDATE() BETWEEN cp.FromDate AND cp.ToDate
      AND (cp.UsageLimit IS NULL OR cp.UsedCount < cp.UsageLimit)
      AND @GrossTotal >= cp.MinOrderTotal
      AND (@StoreEff IS NULL OR cp.StoreId IS NULL OR cp.StoreId = @StoreEff)
      AND (cp.PerCustomerLimit IS NULL OR
           (SELECT COUNT(*) FROM [store].[CouponRedemptions] cr
             WHERE cr.CouponId = cp.CouponId AND cr.CustomerId = @CustomerId) < cp.PerCustomerLimit);

    IF @CouponId IS NULL
        THROW 51330, N'کد تخفیف نامعتبر یا منقضی است.', 1;

    SET @CouponDiscount = CASE @CouponType
        WHEN N'Percent' THEN ROUND(@GrossTotal * @CouponValue / 100.0, 0)
        ELSE @CouponValue END;
    IF @CouponMax IS NOT NULL AND @CouponDiscount > @CouponMax
        SET @CouponDiscount = @CouponMax;
    IF @CouponDiscount > @GrossTotal SET @CouponDiscount = @GrossTotal;
END

-- ── جمع نهایی: Gross − Promo − Coupon ───────────────────────
DECLARE @DiscountTotal DECIMAL(18,2) = @PromoDiscount + @CouponDiscount;
IF @DiscountTotal > @GrossTotal SET @DiscountTotal = @GrossTotal;
DECLARE @Total DECIMAL(18,2) = @GrossTotal - @DiscountTotal;
DECLARE @ItemCount INT = (SELECT COUNT(*) FROM @Cart);

-- ── تسویه ────────────────────────────────────
DECLARE @ChequeAmt DECIMAL(18,2) = ISNULL(@ChequeAmount, 0);
DECLARE @Payments DECIMAL(18,2) = ISNULL(@PayCash, 0) + ISNULL(@PayBank, 0) + @ChequeAmt;
DECLARE @Remainder DECIMAL(18,2) = @Total - @Payments;
IF @Remainder < -0.5 THROW 51085, N'مبلغ تسویه (نقدی+بانک+چک) از کل سفارش بیشتر است.', 1;

-- ── تنظیمات فروشگاه ──────────────────────────
DECLARE @WarehouseId INT, @SalesId INT, @SalesCode NVARCHAR(4000), @SalesTitle NVARCHAR(200),
        @CashId INT, @CashCode NVARCHAR(4000), @CashTitle NVARCHAR(200),
        @BankId INT, @BankCode NVARCHAR(4000), @BankTitle NVARCHAR(200),
        @CashBoxId INT, @BankAccountId INT;
SELECT @WarehouseId = InventoryWarehouseId,
       @SalesId = SalesAccountId, @SalesCode = SalesAccountCode, @SalesTitle = SalesAccountTitle,
       @CashId = CashAccountId, @CashCode = CashAccountCode, @CashTitle = CashAccountTitle,
       @BankId = BankChartAccountId, @BankCode = BankChartAccountCode, @BankTitle = BankChartAccountTitle,
       @CashBoxId = CashBoxId, @BankAccountId = BankAccountId
FROM [store].[StoreSettings] WHERE CompanyId = @CompanyId;
-- Fallback: حساب‌های قدیمی (فقط ChartOfAccounts تخت)
IF @SalesCode IS NULL AND @SalesId IS NOT NULL
    SELECT @SalesCode = a.AccountCode, @SalesTitle = a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId = @SalesId AND a.CompanyId = @CompanyId AND a.IsDeleted = 0;
IF @CashCode IS NULL AND @CashId IS NOT NULL
    SELECT @CashCode = a.AccountCode, @CashTitle = a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId = @CashId AND a.CompanyId = @CompanyId AND a.IsDeleted = 0;
IF @BankCode IS NULL AND @BankId IS NOT NULL
    SELECT @BankCode = a.AccountCode, @BankTitle = a.Title FROM [accounting].[ChartOfAccounts] a WHERE a.AccountId = @BankId AND a.CompanyId = @CompanyId AND a.IsDeleted = 0;
IF @SalesId IS NULL OR @SalesCode IS NULL
    THROW 51081, N'حساب فروش در تنظیمات فروشگاه (اتصال حسابداری) تنظیم نشده است.', 1;

-- لینک حسابداری مشتری
DECLARE @PartyAccountId INT = (SELECT DetailLinkId FROM [treasury].[PartyLinks] WHERE CompanyId = @CompanyId AND PartyId = @CustomerPartyId);
DECLARE @PartyCode NVARCHAR(50) = (SELECT DetailAccountCode FROM [treasury].[PartyLinks] WHERE CompanyId = @CompanyId AND PartyId = @CustomerPartyId);
IF @PartyAccountId IS NULL OR @PartyCode IS NULL
    THROW 51082, N'لینک حسابداری مشتری (تفصیلی) تنظیم نشده است؛ مشتری را دوباره ذخیره کنید.', 1;

BEGIN TRAN;

-- ── کنترل موجودی (پیش از ساخت سفارش) ─────────
DECLARE @Unavailable INT = 0;
SELECT @Unavailable = COUNT(*)
FROM @Cart c
LEFT JOIN [inventory].[Items] it ON it.ItemCode = c.ItemCode AND it.CompanyId = @CompanyId AND it.IsDeleted = 0
WHERE c.ItemCode IS NOT NULL AND c.ItemCode <> N''
  AND  (it.ItemId IS NULL OR it.StockQty < c.Qty + ISNULL((
        SELECT SUM(r.Qty) FROM [inventory].[Reservations] r
        WHERE r.ItemCode = c.ItemCode AND r.Status = N'Active'), 0));
IF @Unavailable > 0
    THROW 51083, N'موجودی انبار برای یک یا چند کالای سفارش کافی نیست.', 1;

-- ── سفارش ────────────────────────────────────
DECLARE @EffectiveOrderDate DATE = @EffDate;
DECLARE @PaymentStatus NVARCHAR(30) = CASE WHEN @Remainder <= 0 THEN N'Paid' WHEN @Payments > 0 THEN N'Partial' ELSE N'Unpaid' END;

INSERT INTO [store].[Orders]
    (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount, TotalAmount, GrossTotal, DiscountTotal,
     PriceListId, PromotionId, CouponId, CurrencyCode, Status,
     PaymentStatus, BalanceRial, PayCash, PayBank, ChequeNumber, ChequeBankId, ChequeAmount, ChequeDueDate,
     CreatedAt, CreatedBy, CompanyId, StoreId)
VALUES
    (N'', @CustomerId, @CustomerName, @EffectiveOrderDate, @ItemCount, @Total, @GrossTotal, @DiscountTotal,
     @PriceListId, @PromoId, @CouponId, N'IRR', N'Invoiced',
     @PaymentStatus, @Remainder, ISNULL(@PayCash, 0), ISNULL(@PayBank, 0),
     ISNULL(@ChequeNumber, N''), @ChequeBankId, @ChequeAmt, @ChequeDueDate,
     SYSUTCDATETIME(), @CreatedBy, @CompanyId, @StoreId);

DECLARE @OrderId INT = SCOPE_IDENTITY();

-- State Machine: تاریخچهٔ وضعیت اولیه (Invoiced — POS یکمرحله‌ای)
INSERT INTO [store].[OrderStatusHistory] (OrderId, FromStatus, ToStatus, Reason, ChangedBy)
VALUES (@OrderId, NULL, N'Invoiced', N'ثبت سفارش', @CreatedBy);
DECLARE @OrderNumber NVARCHAR(50) = N'ORD-' + RIGHT(N'00000' + CAST(@OrderId AS NVARCHAR(10)), 5);
UPDATE [store].[Orders] SET OrderNumber = @OrderNumber WHERE OrderId = @OrderId;

INSERT INTO [store].[OrderItems] (OrderId, ProductId, ProductTitle, Qty, UnitPrice, CreatedAt, CompanyId)
SELECT @OrderId, c.ProductId, c.Title, c.Qty, c.UnitPrice, SYSUTCDATETIME(), @CompanyId FROM @Cart c ORDER BY c.CartItemId;

-- ── مصرف کوپن (اتمی؛ ایندکس یکتا UX_CouponRed_Order idempotent می‌کند) ──
IF @CouponId IS NOT NULL
BEGIN
    INSERT INTO [store].[CouponRedemptions] (CompanyId, CouponId, OrderId, CustomerId, DiscountAmt)
    VALUES (@CompanyId, @CouponId, @OrderId, @CustomerId, @CouponDiscount);
    UPDATE [store].[Coupons] SET UsedCount = UsedCount + 1 WHERE CouponId = @CouponId;
END

DELETE FROM [store].[CartItems] WHERE CustomerId = @CustomerId AND CompanyId = @CompanyId;

-- ── خروج کالا از انبار (FIFO + آزادسازی رزرو) ─
IF @WarehouseId IS NULL
    THROW 51084, N'انبار پیش‌فرض فروشگاه در تنظیمات (اتصال حسابداری) تنظیم نشده است.', 1;

DELETE FROM [inventory].[Reservations] WHERE OrderId = @OrderId;

DECLARE @ItemCode NVARCHAR(50), @Qty DECIMAL(18,3), @UnitPrice DECIMAL(18,2), @InvItemId INT;
DECLARE curItem CURSOR LOCAL FAST_FORWARD FOR SELECT ItemCode, Qty, UnitPrice FROM @Cart WHERE ItemCode IS NOT NULL AND ItemCode <> N'';
OPEN curItem;
FETCH NEXT FROM curItem INTO @ItemCode, @Qty, @UnitPrice;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @InvItemId = ItemId FROM [inventory].[Items] WHERE ItemCode = @ItemCode AND CompanyId = @CompanyId AND IsDeleted = 0;
    IF @InvItemId IS NOT NULL
    BEGIN
        -- مصرف لایه‌های موجودی (FIFO) — هماهنگ با ماژول انبار
        DECLARE @RemQty DECIMAL(18,4) = @Qty, @TotCost DECIMAL(18,2) = 0, @LyId INT, @LyCost DECIMAL(18,2), @LyRem DECIMAL(18,4);
        DECLARE curLayers CURSOR LOCAL FAST_FORWARD FOR
            SELECT LayerId, UnitCost, QtyRemaining FROM [inventory].[StockLayers]
            WHERE ItemId = @InvItemId AND WarehouseId = @WarehouseId AND QtyRemaining > 0 AND CompanyId = @CompanyId
            ORDER BY ReceivedDate, LayerId;
        OPEN curLayers;
        FETCH NEXT FROM curLayers INTO @LyId, @LyCost, @LyRem;
        WHILE @@FETCH_STATUS = 0 AND @RemQty > 0
        BEGIN
            IF @LyRem >= @RemQty
            BEGIN SET @TotCost = @TotCost + @RemQty * @LyCost; UPDATE [inventory].[StockLayers] SET QtyRemaining = QtyRemaining - @RemQty WHERE LayerId = @LyId; SET @RemQty = 0; END
            ELSE
            BEGIN SET @TotCost = @TotCost + @LyRem * @LyCost; SET @RemQty = @RemQty - @LyRem; UPDATE [inventory].[StockLayers] SET QtyRemaining = 0 WHERE LayerId = @LyId; END
            FETCH NEXT FROM curLayers INTO @LyId, @LyCost, @LyRem;
        END
        CLOSE curLayers; DEALLOCATE curLayers;

        -- Fallback: لایه کافی نبود ولی موجودی کافی است → مستقیم با قیمت واحد
        DECLARE @IssueCost DECIMAL(18,2) = CASE WHEN @RemQty = 0 THEN ROUND(@TotCost / @Qty, 2) ELSE @UnitPrice END;

        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId, SourceReference)
        VALUES (N'', N'Issue', @InvItemId, @WarehouseId, NULL, @Qty, @IssueCost, @IssueCost, @EffectiveOrderDate, N'حواله بابت ' + @OrderNumber, N'Posted', @CreatedBy, @CompanyId,
                CONCAT(N'StoreOrder:', @OrderId));
        DECLARE @MvId INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@MvId AS NVARCHAR(10)), 5) WHERE MovementId = @MvId;

        -- در حالت fallback (لایه نبود)، لایهٔ منفی/تازه نمی‌سازیم — فقط موجودی کم می‌شود
        UPDATE [inventory].[Items] SET StockQty = StockQty - @Qty, UpdatedAt = SYSUTCDATETIME() WHERE ItemId = @InvItemId AND CompanyId = @CompanyId;
    END
    FETCH NEXT FROM curItem INTO @ItemCode, @Qty, @UnitPrice;
END
CLOSE curItem; DEALLOCATE curItem;

-- ── دفتر مشتری (OrderLedger) ─────────────────
INSERT INTO [store].[OrderLedger]
    (CompanyId, CustomerId, OrderId, EntryDate, EntryType, DebitRial, CreditRial, Description, CreatedBy)
VALUES
    (@CompanyId, @CustomerId, @OrderId, @EffectiveOrderDate, N'OrderSale', @Total, @Payments,
     N'فروش ' + @OrderNumber + CASE WHEN @Remainder > 0 THEN N'؛ نسیه: ' + FORMAT(@Remainder, N'#,##0') + N' ریال' ELSE N'' END, @CreatedBy);

-- ── خزانه: نقدی / بانک / چک (دریافت) ─────────
IF @ChequeAmt > 0
BEGIN
    IF ISNULL(@ChequeNumber, N'') = N'' THROW 51096, N'شماره چک الزامی است.', 1;
    IF @ChequeBankId IS NULL THROW 51097, N'بانک چک الزامی است.', 1;
    INSERT INTO [treasury].[Cheques](ChequeNumber, BankId, Amount, DueDate, Direction, Status, CreatedAt, CreatedBy, CompanyId, SourceReference)
    VALUES(@ChequeNumber, @ChequeBankId, @ChequeAmt, ISNULL(@ChequeDueDate, @EffectiveOrderDate), N'In', N'Pending', SYSUTCDATETIME(), @CreatedBy, @CompanyId, CONCAT(N'StoreOrder:', @OrderId));
END
IF ISNULL(@PayCash, 0) > 0
BEGIN
    IF @CashBoxId IS NULL THROW 51076, N'صندوق پیش‌فرض فروشگاه در تنظیمات تنظیم نشده است.', 1;
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy, CompanyId)        VALUES (N'', @EffectiveOrderDate, N'In', @PayCash, N'IRR', NULL, @CashBoxId, N'دریافت نقدی ' + @OrderNumber, CONCAT(N'StoreOrder:', @OrderId), N'Posted', @CreatedBy, @CompanyId);
    DECLARE @CM1 INT = SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements] SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(@CM1 AS NVARCHAR(10)), 5) WHERE MovementId = @CM1;
    UPDATE [treasury].[CashBoxes] SET Balance = Balance + @PayCash WHERE CashBoxId = @CashBoxId AND CompanyId = @CompanyId;
END
IF ISNULL(@PayBank, 0) > 0
BEGIN
    IF @BankAccountId IS NULL THROW 51076, N'حساب بانکی پیش‌فرض فروشگاه در تنظیمات تنظیم نشده است.', 1;
    INSERT INTO [treasury].[CashMovements]
        (MovementNumber, MovementDate, Direction, Amount, CurrencyCode, AccountId, CashBoxId, Description, SourceReference, Status, CreatedBy, CompanyId)        VALUES (N'', @EffectiveOrderDate, N'In', @PayBank, N'IRR', @BankAccountId, NULL, N'دریافت بانکی ' + @OrderNumber, CONCAT(N'StoreOrder:', @OrderId), N'Posted', @CreatedBy, @CompanyId);
    DECLARE @CM2 INT = SCOPE_IDENTITY();
    UPDATE [treasury].[CashMovements] SET MovementNumber = N'CSH-' + RIGHT(N'00000' + CAST(@CM2 AS NVARCHAR(10)), 5) WHERE MovementId = @CM2;
    UPDATE [treasury].[BankAccounts] SET Balance = Balance + @PayBank WHERE AccountId = @BankAccountId AND CompanyId = @CompanyId;
END

-- ── سند حسابداری (سند یاداشت — Status='Note') ─
DECLARE @NextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber)) FROM [accounting].[Documents] WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;
INSERT INTO [accounting].[Documents]
    (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId, SourceReference)
VALUES
    (RIGHT(N'00000000' + CAST(@NextNum AS NVARCHAR(10)), 8), @EffectiveOrderDate, N'Sale', @CustomerName, @Total, N'IRR', N'Note', @CreatedBy, 0, @CompanyId, @FiscalYearId, CONCAT(N'StoreOrder:', @OrderId));
DECLARE @DocumentId INT = SCOPE_IDENTITY();

IF @Remainder > 0
    INSERT INTO [accounting].[DocumentLines](DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    VALUES(@DocumentId, @PartyAccountId, @PartyCode, @CustomerName, N'نسیه ' + @OrderNumber, @Remainder, 0);
IF ISNULL(@PayCash, 0) > 0 AND @CashId IS NOT NULL AND @CashCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    VALUES(@DocumentId, @CashId, @CashCode, @CashTitle, N'دریافت نقدی ' + @OrderNumber, @PayCash, 0);
IF ISNULL(@PayBank, 0) > 0 AND @BankId IS NOT NULL AND @BankCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    VALUES(@DocumentId, @BankId, @BankCode, @BankTitle, N'دریافت بانکی ' + @OrderNumber, @PayBank, 0);
IF @ChequeAmt > 0 AND @BankId IS NOT NULL AND @BankCode IS NOT NULL
    INSERT INTO [accounting].[DocumentLines](DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
    VALUES(@DocumentId, @BankId, @BankCode, @BankTitle, N'دریافت چک ' + ISNULL(@ChequeNumber, N'') + N' ' + @OrderNumber, @ChequeAmt, 0);
INSERT INTO [accounting].[DocumentLines](DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
VALUES(@DocumentId, @SalesId, @SalesCode, @SalesTitle, N'فروش فروشگاه ' + @OrderNumber, 0, @Total);

UPDATE [store].[Orders] SET DocumentId = @DocumentId WHERE OrderId = @OrderId;

    -- لنگر حسابداری روی ردیف‌های خزانهٔ همین سفارش (شمارهٔ مشترک StoreOrder:{OrderId})
    UPDATE [treasury].[CashMovements] SET DocumentId = @DocumentId WHERE SourceReference = CONCAT(N'StoreOrder:', @OrderId);
    UPDATE [treasury].[Cheques]        SET DocumentId = @DocumentId WHERE SourceReference = CONCAT(N'StoreOrder:', @OrderId);

COMMIT;
SELECT @OrderId AS OrderId, @OrderNumber AS OrderNumber, @GrossTotal AS GrossTotal,
       @DiscountTotal AS DiscountTotal, @PromoDiscount AS PromotionDiscount, @CouponDiscount AS CouponDiscount,
       @Total AS TotalAmount, @Remainder AS BalanceRial, @DocumentId AS DocumentId;
