-- =============================================
-- Tarazin.Data/Scripts/inventory/TransferInsert.sql
-- Schema: inventory
-- Execute. انتقال بین انبارها: خروج از مبدأ + ورود به مقصد + سند حسابداری.
-- پارامترها:
--   @TransferDate, @FromWarehouseId, @ToWarehouseId, @Description,
--   @CompanyId, @CreatedBy, @FiscalYearId
--   @LinesJson — [{ ItemId, Qty }]
-- =============================================
IF @FromWarehouseId = @ToWarehouseId
    THROW 51060, N'انبار مبدأ و مقصد یکسان است.', 1;

DECLARE @CostingMethod NVARCHAR(30) = ISNULL(
    (SELECT CostingMethod FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), N'WeightedAverage');

BEGIN TRAN;

    INSERT INTO [inventory].[WarehouseTransfers]
        (TransferNumber, TransferDate, FromWarehouseId, ToWarehouseId, Description, Status, CompanyId, CreatedBy)
    VALUES
        (N'', @TransferDate, @FromWarehouseId, @ToWarehouseId, @Description, N'Posted', @CompanyId, @CreatedBy);
    DECLARE @TransferId INT = SCOPE_IDENTITY();
    DECLARE @TransferNumber NVARCHAR(50) = N'TRF-' + RIGHT(N'00000' + CAST(@TransferId AS NVARCHAR(10)), 5);
    UPDATE [inventory].[WarehouseTransfers] SET TransferNumber = @TransferNumber WHERE TransferId = @TransferId;

    -- Process lines
    DECLARE @ItemId INT, @Qty DECIMAL(18,3);
    DECLARE curLine CURSOR LOCAL FAST_FORWARD FOR
        SELECT [ItemId], [Qty] FROM OPENJSON(@LinesJson) WITH (ItemId INT, Qty DECIMAL(18,3));
    OPEN curLine;
    FETCH NEXT FROM curLine INTO @ItemId, @Qty;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Determine cost (WA = current item price; FIFO = consume layers from source)
        DECLARE @UnitCost DECIMAL(18,2) = 0;
        IF @CostingMethod = N'WeightedAverage'
            SET @UnitCost = ISNULL((SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId AND CompanyId = @CompanyId), 0);
        ELSE
        BEGIN
            -- Consume layers from source warehouse (same logic as MovementInsert)
            DECLARE @RemQty DECIMAL(18,3) = @Qty, @TotCost DECIMAL(18,2) = 0;
            DECLARE @LyId INT, @LyCost DECIMAL(18,2), @LyRem DECIMAL(18,3);
            DECLARE curLayers CURSOR LOCAL FAST_FORWARD FOR
                SELECT LayerId, UnitCost, QtyRemaining FROM [inventory].[StockLayers]
                WHERE ItemId = @ItemId AND WarehouseId = @FromWarehouseId AND QtyRemaining > 0 AND CompanyId = @CompanyId
                ORDER BY
                    CASE WHEN @CostingMethod = N'LIFO' THEN ReceivedDate END DESC,
                    CASE WHEN @CostingMethod = N'LIFO' THEN LayerId END DESC,
                    CASE WHEN @CostingMethod <> N'LIFO' THEN ReceivedDate END ASC,
                    CASE WHEN @CostingMethod <> N'LIFO' THEN LayerId END ASC;
            OPEN curLayers;
            FETCH NEXT FROM curLayers INTO @LyId, @LyCost, @LyRem;
            WHILE @@FETCH_STATUS = 0 AND @RemQty > 0
            BEGIN
                IF @LyRem >= @RemQty
                BEGIN
                    SET @TotCost = @TotCost + @RemQty * @LyCost;
                    UPDATE [inventory].[StockLayers] SET QtyRemaining = QtyRemaining - @RemQty WHERE LayerId = @LyId;
                    SET @RemQty = 0;
                END
                ELSE
                BEGIN
                    SET @TotCost = @TotCost + @LyRem * @LyCost;
                    SET @RemQty = @RemQty - @LyRem;
                    UPDATE [inventory].[StockLayers] SET QtyRemaining = 0 WHERE LayerId = @LyId;
                END
                FETCH NEXT FROM curLayers INTO @LyId, @LyCost, @LyRem;
            END
            CLOSE curLayers; DEALLOCATE curLayers;
            SET @UnitCost = CASE WHEN @Qty > 0 THEN ROUND(@TotCost / @Qty, 2) ELSE 0 END;
        END

        -- Transfer line
        INSERT INTO [inventory].[TransferLines] (TransferId, ItemId, Qty, UnitCost)
        VALUES (@TransferId, @ItemId, @Qty, @UnitCost);

        -- Issue from source
        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId, SourceReference)
        VALUES (N'', N'Issue', @ItemId, @FromWarehouseId, @Qty, @UnitCost, @UnitCost, @TransferDate,
                N'انتقال به مقصد ' + @TransferNumber, N'Posted', @CreatedBy, @CompanyId,
                CONCAT(N'Transfer:', @TransferId));
        DECLARE @Mid1 INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid1 AS NVARCHAR(10)), 5) WHERE MovementId = @Mid1;

        -- Receipt at destination
        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId, SourceReference)
        VALUES (N'', N'Receipt', @ItemId, @ToWarehouseId, @Qty, @UnitCost, @UnitCost, @TransferDate,
                N'انتقال از مبدأ ' + @TransferNumber, N'Posted', @CreatedBy, @CompanyId,
                CONCAT(N'Transfer:', @TransferId));
        DECLARE @Mid2 INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid2 AS NVARCHAR(10)), 5) WHERE MovementId = @Mid2;

        -- New stock layer at destination
        INSERT INTO [inventory].[StockLayers]
            (ItemId, WarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
        VALUES (@ItemId, @ToWarehouseId, @Mid2, @Qty, @UnitCost, @TransferDate, @CompanyId);

        FETCH NEXT FROM curLine INTO @ItemId, @Qty;
    END
    CLOSE curLine; DEALLOCATE curLine;

    -- StockQty (total across warehouses) unchanged — items just moved between warehouses

COMMIT;
SELECT @TransferId AS TransferId, @TransferNumber AS TransferNumber;
