-- =============================================
-- Tarazin.Shared/Data/Scripts/inventory/MovementInsert.sql
-- Schema: inventory
-- Execute. Posts movement + updates stock + emits InventoryMovement (ADR-002).
-- =============================================
DECLARE @ItemCode NVARCHAR(50) = (SELECT ItemCode FROM [inventory].[Items] WHERE ItemId = @ItemId);

IF @ItemCode IS NULL
    THROW 51002, N'کالا یافت نشد', 1;

IF @MovementType = N'Issue'
   AND (SELECT StockQty FROM [inventory].[Items] WHERE ItemId = @ItemId) < @Qty
    THROW 51003, N'موجودی کافی نیست', 1;

BEGIN TRAN;
    INSERT INTO [inventory].[Movements]
        (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, MovementDate, Description, Status, CreatedBy)
    VALUES
        (N'', @MovementType, @ItemId, @WarehouseId, @Qty, @UnitPrice, @MovementDate, @Description, N'Posted', @CreatedBy);

    DECLARE @Mid INT = SCOPE_IDENTITY();
    UPDATE [inventory].[Movements]
    SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5)
    WHERE MovementId = @Mid;

    UPDATE [inventory].[Items]
    SET StockQty = StockQty + CASE WHEN @MovementType IN (N'Receipt', N'Adjustment') THEN @Qty ELSE -@Qty END,
        UpdatedAt = SYSUTCDATETIME()
    WHERE ItemId = @ItemId;

    INSERT INTO [inventory].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    VALUES (N'InventoryMovement', CONCAT(N'MovementId=', @Mid),
        (SELECT @Mid AS MovementId, @ItemCode AS ItemCode, @MovementType AS MovementType,
                @Qty AS Qty, @UnitPrice AS UnitPrice, @MovementDate AS MovementDate, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1);
COMMIT;
