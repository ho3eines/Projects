-- =============================================
-- Tarazin.Data/Scripts/inventory/StocktakeRun.sql
-- Schema: inventory
-- Execute. عملیات ویژه: انبارگردانی — ثبت شمارش و تعدیل موجودی (انبار/انبارک مشخص).
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
                (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
            VALUES
                (N'', N'Adjustment', @ItemId, @WarehouseId, @SubWarehouseId, @Diff, @UnitCost, @UnitCost,
                 CAST(SYSDATETIME() AS DATE), N'انبارگردانی: افزایش موجودی', N'Posted', @CreatedBy, @CompanyId);
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
                (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
            VALUES
                (N'', N'Adjustment', @ItemId, @WarehouseId, @SubWarehouseId, @OutQty, @CostPrice, @CostPrice,
                 CAST(SYSDATETIME() AS DATE), N'انبارگردانی: کاهش موجودی', N'Posted', @CreatedBy, @CompanyId);
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
    COMMIT;
END
