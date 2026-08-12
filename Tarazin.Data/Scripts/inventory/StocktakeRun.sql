-- =============================================
-- Tarazin.Data/Scripts/inventory/StocktakeRun.sql
-- Schema: inventory
-- Execute. عملیات ویژه: انبارگردانی — ثبت شمارش و تعدیل موجودی.
-- =============================================
DECLARE @Current DECIMAL(18,3) = (SELECT StockQty FROM [inventory].[Items] WHERE ItemId = @ItemId);
IF @Current IS NULL
    THROW 51004, N'کالا یافت نشد', 1;

DECLARE @Diff DECIMAL(18,3) = @CountedQty - @Current;
IF @Diff <> 0
BEGIN
    BEGIN TRAN;
        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, MovementDate, Description, Status, CreatedBy)
        VALUES
            (N'', N'Adjustment', @ItemId, NULL, ABS(@Diff), (SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId),
             CAST(SYSDATETIME() AS DATE), N'انبارگردانی: تعدیل موجودی', N'Posted', @CreatedBy);

        DECLARE @Mid INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements]
        SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5)
        WHERE MovementId = @Mid;

        UPDATE [inventory].[Items] SET StockQty = @CountedQty, UpdatedAt = SYSUTCDATETIME() WHERE ItemId = @ItemId;

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
