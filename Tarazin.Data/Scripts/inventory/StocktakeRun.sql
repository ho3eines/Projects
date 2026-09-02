-- =============================================
-- Tarazin.Data/Scripts/inventory/StocktakeRun.sql
-- Schema: inventory
-- Cross-schema: accounting, central
-- Execute. عملیات ویژه: انبارگردانی — ثبت شمارش و تعدیل موجودی (انبار/انبارک مشخص)
-- + سند حسابداری مغایرت (اگر تنظیمات انبار فعال و حساب مقابل تعدیل ست شده باشد).
-- پارامترها: @ItemId, @WarehouseId, @SubWarehouseId, @CountedQty, @FiscalYearId,
--            @CompanyId, @CreatedBy
-- =============================================
IF @WarehouseId IS NULL OR @WarehouseId = 0
    THROW 51004, N'انبار را انتخاب کنید.', 1;

-- موجودی لایه‌ای فعلی در این انبار/انبارک
DECLARE @Current DECIMAL(18,3) = ISNULL((
    SELECT SUM(QtyRemaining) FROM [inventory].[StockLayers]
    WHERE ItemId = @ItemId AND WarehouseId = @WarehouseId
      AND ISNULL(SubWarehouseId, 0) = ISNULL(@SubWarehouseId, 0)
      AND QtyRemaining > 0), 0);

DECLARE @Diff DECIMAL(18,3) = @CountedQty - @Current;
IF @Diff <> 0
BEGIN
    BEGIN TRAN;
        -- تعدیل مثبت → رسید (لایهٔ جدید با قیمت جاری)؛ تعدیل منفی → حواله (مصرف لایه‌ها)
        IF @Diff > 0
        BEGIN
            DECLARE @UnitCost DECIMAL(18,2) = ISNULL((SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId), 0);
            INSERT INTO [inventory].[Movements]
                (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId, SourceReference)
            VALUES
                (N'', N'Adjustment', @ItemId, @WarehouseId, @SubWarehouseId, @Diff, @UnitCost, @UnitCost,
                 CAST(SYSDATETIME() AS DATE), N'انبارگردانی: افزایش موجودی', N'Posted', @CreatedBy, @CompanyId,
                 N'Stocktake');
            DECLARE @Mid INT = SCOPE_IDENTITY();
            UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5) WHERE MovementId = @Mid;

            INSERT INTO [inventory].[StockLayers] (ItemId, WarehouseId, SubWarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
            VALUES (@ItemId, @WarehouseId, @SubWarehouseId, @Mid, @Diff, @UnitCost, CAST(SYSDATETIME() AS DATE), @CompanyId);
        END
        ELSE
        BEGIN
            DECLARE @OutQty DECIMAL(18,3) = ABS(@Diff);
            DECLARE @RemainingQty DECIMAL(18,3) = @OutQty;
            DECLARE @TotalCost DECIMAL(18,2) = 0;
            DECLARE @LayerId INT, @LayerCost DECIMAL(18,2), @LayerRem DECIMAL(18,3);

            DECLARE layer_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT LayerId, UnitCost, QtyRemaining
                FROM [inventory].[StockLayers]
                WHERE ItemId = @ItemId AND WarehouseId = @WarehouseId
                  AND ISNULL(SubWarehouseId, 0) = ISNULL(@SubWarehouseId, 0)
                  AND QtyRemaining > 0
                ORDER BY ReceivedDate, LayerId;
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
            DECLARE @CostPrice DECIMAL(18,2) = ROUND(@TotalCost / @OutQty, 2);

            INSERT INTO [inventory].[Movements]
                (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId, SourceReference)
            VALUES
                (N'', N'Adjustment', @ItemId, @WarehouseId, @SubWarehouseId, @OutQty, @CostPrice, @CostPrice,
                 CAST(SYSDATETIME() AS DATE), N'انبارگردانی: کاهش موجودی', N'Posted', @CreatedBy, @CompanyId,
                 N'Stocktake');
            DECLARE @Mid2 INT = SCOPE_IDENTITY();
            UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid2 AS NVARCHAR(10)), 5) WHERE MovementId = @Mid2;
            SET @Mid = @Mid2;
        END

        -- به‌روزرسانی جمع کل کالا
        UPDATE [inventory].[Items] SET StockQty = StockQty + @Diff, UpdatedAt = SYSUTCDATETIME() WHERE ItemId = @ItemId;

        INSERT INTO [inventory].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
        VALUES (N'InventoryMovement', CONCAT(N'MovementId=', @Mid),
            (SELECT @Mid AS MovementId,
                    (SELECT ItemCode FROM [inventory].[Items] WHERE ItemId = @ItemId) AS ItemCode,
                    N'Adjustment' AS MovementType, @Diff AS Qty,
                    (SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId) AS UnitPrice,
                    CAST(SYSDATETIME() AS DATE) AS MovementDate,
                    N'انبارگردانی: تعدیل موجودی' AS Description
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);

        -- ── سند حسابداری مغایرت (اگر تنظیمات فعال و حساب‌ها آماده باشد) ──
        -- انبارگردانی هرگز به دلیل نبود تنظیمات حسابداری متوقف نمی‌شود؛ سند فقط در
        -- صورت کامل‌بودن تنظیمات (حساب‌ها + سال مالی) ساخته می‌شود.
        DECLARE @AdjSettingsEnabled BIT = ISNULL((SELECT IsEnabled FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), 0);
        DECLARE @AdjDocumentId INT = NULL;
        IF @AdjSettingsEnabled = 1 AND @Diff <> 0
        BEGIN
            DECLARE @AdjInvAccountId INT, @AdjInvCode NVARCHAR(4000), @AdjInvTitle NVARCHAR(200);
            DECLARE @AdjAccountId INT, @AdjCode NVARCHAR(4000), @AdjTitle NVARCHAR(200);
            SELECT @AdjInvAccountId = InventoryAccountId, @AdjInvCode = InventoryAccountCode, @AdjInvTitle = InventoryAccountTitle,
                   @AdjAccountId = AdjustmentAccountId, @AdjCode = AdjustmentAccountCode, @AdjTitle = AdjustmentAccountTitle
            FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId;

            IF @AdjInvAccountId IS NULL OR @AdjAccountId IS NULL OR @FiscalYearId IS NULL
                SET @AdjDocumentId = NULL;  -- سند ساخته نمی‌شود (بدون خطا)
            ELSE
            BEGIN
            DECLARE @AdjAmount DECIMAL(18,2) = ROUND(ABS(@Diff) * CASE WHEN @Diff > 0 THEN @UnitCost ELSE @CostPrice END, 2);
            DECLARE @AdjNextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber))
                                              FROM [accounting].[Documents]
                                              WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;

            INSERT INTO [accounting].[Documents]
                (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode,
                 Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId, SourceReference)
            VALUES
                (RIGHT(N'00000000' + CAST(@AdjNextNum AS NVARCHAR(10)), 8), CAST(SYSDATETIME() AS DATE),
                 N'StocktakeAdjustment', N'انبارگردانی', @AdjAmount, N'IRR', N'Note', @CreatedBy, 0,
                 @CompanyId, @FiscalYearId, CONCAT(N'Stocktake:', @Mid));
            SET @AdjDocumentId = SCOPE_IDENTITY();

            IF @Diff > 0
            BEGIN
                -- افزایش موجودی: بدهکار موجودی کالا / بستانکار حساب مقابل تعدیل
                INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                VALUES (@AdjDocumentId, @AdjInvAccountId, @AdjInvCode, @AdjInvTitle, N'انبارگردانی: افزایش موجودی', @AdjAmount, 0);
                INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                VALUES (@AdjDocumentId, @AdjAccountId, @AdjCode, @AdjTitle, N'انبارگردانی: افزایش موجودی', 0, @AdjAmount);
            END
            ELSE
            BEGIN
                -- کاهش موجودی: بستانکار موجودی کالا / بدهکار حساب مقابل تعدیل
                INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                VALUES (@AdjDocumentId, @AdjAccountId, @AdjCode, @AdjTitle, N'انبارگردانی: کاهش موجودی', @AdjAmount, 0);
                INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                VALUES (@AdjDocumentId, @AdjInvAccountId, @AdjInvCode, @AdjInvTitle, N'انبارگردانی: کاهش موجودی', 0, @AdjAmount);
            END
            END
        END
    COMMIT;
END

-- خروجی: شناسهٔ سند حسابداری انبارگردانی (اگر ساخته شده باشد؛ وگرنه NULL)
SELECT @AdjDocumentId AS DocumentId;
