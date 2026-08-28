-- =============================================
-- Tarazin.Data/Scripts/inventory/MovementInsert.sql
-- Schema: inventory
-- Cross-schema: accounting (سند خودکار), central
-- Execute. ثبت حرکت انبار + به‌روزرسانی موجودی + لایه‌های قیمت‌گذاری + سند حسابداری.
-- روش قیمت‌گذاری از InventorySettings شرکت خوانده می‌شود:
--   WeightedAverage — میانگین موزون (پس از هر رسید میانگین به‌روز می‌شود)
--   FIFO — اولین خرید، اولین مصرف (قدیمی‌ترین لایه اول خارج می‌شود)
--   LIFO — آخرین خرید، اولین مصرف (جدیدترین لایه اول خارج می‌شود)
-- =============================================
IF @MovementType NOT IN (N'Receipt', N'Issue', N'Adjustment')
    THROW 51006, N'نوع حرکت نامعتبر است (Receipt/Issue/Adjustment)', 1;

DECLARE @ItemCode NVARCHAR(50) = (SELECT ItemCode FROM [inventory].[Items] WHERE ItemId = @ItemId AND IsDeleted = 0);
IF @ItemCode IS NULL
    THROW 51002, N'کالا یافت نشد', 1;

DECLARE @CostingMethod NVARCHAR(30) = (SELECT CostingMethod FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId);
IF @CostingMethod IS NULL
    SET @CostingMethod = N'WeightedAverage';

BEGIN TRAN;
    -- ── ثبت حرکت ──
    DECLARE @EffectiveQty DECIMAL(18,3) = @Qty;
    DECLARE @Direction INT = CASE WHEN @MovementType = N'Issue' THEN -1 ELSE 1 END;
    -- تعدیل: اگر تعداد منفی ارسال شد، جهت معکوس می‌شود
    IF @MovementType = N'Adjustment' AND @Qty < 0
    BEGIN
        SET @EffectiveQty = ABS(@Qty);
        SET @Direction = -1;
    END

    -- قیمت تمام‌شدهٔ خروج: برای رسید = قیمت واحد ورودی؛ برای خروج = طبق روش قیمت‌گذاری
    DECLARE @CostPrice DECIMAL(18,2) = 0;

    IF @Direction = 1
    BEGIN
        SET @CostPrice = ISNULL(@UnitPrice, 0);
        -- لایهٔ جدید موجودی
        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
        VALUES
            (N'', @MovementType, @ItemId, @WarehouseId, @SubWarehouseId, @EffectiveQty, @CostPrice, @CostPrice, @MovementDate, @Description, N'Posted', @CreatedBy, @CompanyId);
        DECLARE @Mid INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements]
        SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5)
        WHERE MovementId = @Mid;

        INSERT INTO [inventory].[StockLayers]
            (ItemId, WarehouseId, SubWarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
        VALUES
            (@ItemId, @WarehouseId, @SubWarehouseId, @Mid, @EffectiveQty, @CostPrice, @MovementDate, @CompanyId);

        -- میانگین موزون: قیمت کالا = (ارزش موجودی + ارزش رسید) / (تعداد + تعداد رسید)
        IF @CostingMethod = N'WeightedAverage'
        BEGIN
            DECLARE @CurQty DECIMAL(18,3) = (SELECT StockQty FROM [inventory].[Items] WHERE ItemId = @ItemId);
            DECLARE @CurPrice DECIMAL(18,2) = (SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId);
            IF @CurQty IS NULL OR @CurQty = 0 OR @CurPrice IS NULL OR @CurPrice = 0
                UPDATE [inventory].[Items] SET UnitPrice = @CostPrice WHERE ItemId = @ItemId;
            ELSE
                UPDATE [inventory].[Items]
                SET UnitPrice = ROUND((@CurQty * @CurPrice + @EffectiveQty * @CostPrice) / (@CurQty + @EffectiveQty), 2)
                WHERE ItemId = @ItemId;
        END
    END
    ELSE
    BEGIN
        -- ── مصرف از لایه‌ها طبق روش قیمت‌گذاری (Issue/Adjustment-کاهش) ──
        DECLARE @RemainingQty DECIMAL(18,3) = @EffectiveQty;
        DECLARE @TotalCost DECIMAL(18,2) = 0;
        DECLARE @LayerId INT, @LayerCost DECIMAL(18,2), @LayerRem DECIMAL(18,3);

        -- موجودی لایه‌ای کافی؟
        DECLARE @LayerStock DECIMAL(18,3) = ISNULL((
            SELECT SUM(QtyRemaining) FROM [inventory].[StockLayers]
            WHERE ItemId = @ItemId AND WarehouseId = @WarehouseId
              AND ISNULL(SubWarehouseId, 0) = ISNULL(@SubWarehouseId, 0)
              AND QtyRemaining > 0), 0);
        IF @LayerStock < @EffectiveQty
            THROW 51003, N'موجودی کافی نیست', 1;

        DECLARE layer_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT LayerId, UnitCost, QtyRemaining
            FROM [inventory].[StockLayers]
            WHERE ItemId = @ItemId AND WarehouseId = @WarehouseId
              AND ISNULL(SubWarehouseId, 0) = ISNULL(@SubWarehouseId, 0)
              AND QtyRemaining > 0
            ORDER BY
                CASE WHEN @CostingMethod = N'LIFO' THEN ReceivedDate END DESC,
                CASE WHEN @CostingMethod = N'LIFO' THEN LayerId END DESC,
                CASE WHEN @CostingMethod <> N'LIFO' THEN ReceivedDate END ASC,
                CASE WHEN @CostingMethod <> N'LIFO' THEN LayerId END ASC;
        OPEN layer_cursor;
        FETCH NEXT FROM layer_cursor INTO @LayerId, @LayerCost, @LayerRem;
        WHILE @@FETCH_STATUS = 0 AND @RemainingQty > 0
        BEGIN
            IF @LayerRem >= @RemainingQty
            BEGIN
                SET @TotalCost = @TotalCost + @RemainingQty * @LayerCost;
                UPDATE [inventory].[StockLayers] SET QtyRemaining = QtyRemaining - @RemainingQty WHERE LayerId = @LayerId;
                SET @RemainingQty = 0;
            END
            ELSE
            BEGIN
                SET @TotalCost = @TotalCost + @LayerRem * @LayerCost;
                SET @RemainingQty = @RemainingQty - @LayerRem;
                UPDATE [inventory].[StockLayers] SET QtyRemaining = 0 WHERE LayerId = @LayerId;
            END
            FETCH NEXT FROM layer_cursor INTO @LayerId, @LayerCost, @LayerRem;
        END
        CLOSE layer_cursor;
        DEALLOCATE layer_cursor;

        -- میانگین موزون: قیمت خروج = قیمت جاری کالا (میانگین)
        -- FIFO/LIFO: قیمت خروج = میانگین موزون قیمت لایه‌های مصرف‌شده
        IF @CostingMethod = N'WeightedAverage'
            SET @CostPrice = ISNULL((SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId), 0);
        ELSE
            SET @CostPrice = ROUND(@TotalCost / @EffectiveQty, 2);

        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
        VALUES
            (N'', @MovementType, @ItemId, @WarehouseId, @SubWarehouseId, @EffectiveQty, @CostPrice, @CostPrice, @MovementDate, @Description, N'Posted', @CreatedBy, @CompanyId);
        DECLARE @Mid2 INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements]
        SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid2 AS NVARCHAR(10)), 5)
        WHERE MovementId = @Mid2;
        SET @Mid = @Mid2;
    END

    -- ── به‌روزرسانی موجودی کالا (جمع کل همهٔ انبارها) ──
    UPDATE [inventory].[Items]
    SET StockQty = StockQty + (@Direction * @EffectiveQty),
        UpdatedAt = SYSUTCDATETIME()
    WHERE ItemId = @ItemId;

    -- ── سند حسابداری خودکار (در صورت فعال بودن تنظیمات) ──
    --   رسید: بدهکار حساب انبار ← بستانکار حساب مقابل رسید
    --   حواله: بدهکار حساب مقابل حواله ← بستانکار حساب انبار
    --   تعدیل: بدون سند (اصلاح موجودی)
    DECLARE @SettingsEnabled BIT = ISNULL((SELECT IsEnabled FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), 0);
    IF @SettingsEnabled = 1 AND @MovementType IN (N'Receipt', N'Issue')
    BEGIN
        IF @FiscalYearId IS NULL
            THROW 51027, N'سال مالی فعال برای ثبت سند حسابداری انتخاب نشده است.', 1;

        DECLARE @InvAccountId INT, @InvCode NVARCHAR(4000), @InvTitle NVARCHAR(200);
        DECLARE @ContraAccountId INT, @ContraCode NVARCHAR(4000), @ContraTitle NVARCHAR(200);
        SELECT @InvAccountId = InventoryAccountId, @InvCode = InventoryAccountCode, @InvTitle = InventoryAccountTitle,
               @ContraAccountId = CASE WHEN @MovementType = N'Receipt' THEN ReceiptContraAccountId ELSE IssueContraAccountId END,
               @ContraCode = CASE WHEN @MovementType = N'Receipt' THEN ReceiptContraAccountCode ELSE IssueContraAccountCode END,
               @ContraTitle = CASE WHEN @MovementType = N'Receipt' THEN ReceiptContraAccountTitle ELSE IssueContraAccountTitle END
        FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId;

        IF @InvAccountId IS NULL OR @InvCode IS NULL
            THROW 51038, N'حساب انبار در تنظیمات انبار تنظیم نشده است.', 1;
        IF @ContraAccountId IS NULL OR @ContraCode IS NULL
            THROW 51039, N'حساب مقابل رسید/حواله در تنظیمات انبار تنظیم نشده است.', 1;

        DECLARE @MovementNumber NVARCHAR(50) = (SELECT MovementNumber FROM [inventory].[Movements] WHERE MovementId = @Mid);
        DECLARE @NextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber))
                                       FROM [accounting].[Documents]
                                       WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;
        DECLARE @DocAmount DECIMAL(18,2) = ROUND(@EffectiveQty * @CostPrice, 2);

        INSERT INTO [accounting].[Documents]
            (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
        VALUES
            (RIGHT(N'00000000' + CAST(@NextNum AS NVARCHAR(10)), 8), @MovementDate,
             CASE WHEN @MovementType = N'Receipt' THEN N'InventoryReceipt' ELSE N'InventoryIssue' END,
             ISNULL(@Description, N''), @DocAmount, N'IRR',
             N'Note', @CreatedBy, 0, @CompanyId, @FiscalYearId);
        DECLARE @DocumentId INT = SCOPE_IDENTITY();

        DECLARE @InvDebit DECIMAL(18,2) = CASE WHEN @MovementType = N'Receipt' THEN @DocAmount ELSE 0 END;
        DECLARE @InvCredit DECIMAL(18,2) = CASE WHEN @MovementType = N'Issue' THEN @DocAmount ELSE 0 END;
        DECLARE @ContraDebit DECIMAL(18,2) = CASE WHEN @MovementType = N'Issue' THEN @DocAmount ELSE 0 END;
        DECLARE @ContraCredit DECIMAL(18,2) = CASE WHEN @MovementType = N'Receipt' THEN @DocAmount ELSE 0 END;

        INSERT INTO [accounting].[DocumentLines]
            (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES
            (@DocumentId, @InvAccountId, @InvCode, @InvTitle,
             CASE WHEN @MovementType = N'Receipt' THEN N'رسید ' + @MovementNumber ELSE N'حواله ' + @MovementNumber END,
             @InvDebit, @InvCredit);

        INSERT INTO [accounting].[DocumentLines]
            (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES
            (@DocumentId, @ContraAccountId, @ContraCode, @ContraTitle,
             CASE WHEN @MovementType = N'Receipt' THEN N'عکس رسید ' + @MovementNumber ELSE N'عکس حواله ' + @MovementNumber END,
             @ContraDebit, @ContraCredit);
    END

    -- ── رویداد (ADR-002) ──
    INSERT INTO [inventory].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'InventoryMovement', CONCAT(N'MovementId=', @Mid),
        (SELECT @Mid AS MovementId, @ItemCode AS ItemCode, @MovementType AS MovementType,
                @EffectiveQty AS Qty, @CostPrice AS UnitPrice, @MovementDate AS MovementDate, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
COMMIT;
