-- =============================================
-- Tarazin.Data/Scripts/inventory/ReturnInsert.sql
-- Schema: inventory
-- Execute. ثبت برگشت خرید یا فروش + اصلاح موجودی + سند حسابداری.
-- پارامترها:
--   @ReturnType (Purchase | Sales), @ReturnDate, @InvoiceId, @WarehouseId,
--   @Description, @CompanyId, @FiscalYearId, @CreatedBy
--   @LinesJson — [{ InvoiceLineId, Qty }]
-- =============================================
DECLARE @IsPurchase BIT = CASE WHEN @ReturnType = N'Purchase' THEN 1 ELSE 0 END;
DECLARE @CostingMethod NVARCHAR(30) = ISNULL(
    (SELECT CostingMethod FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), N'WeightedAverage');

BEGIN TRAN;

    -- Return header
    IF @IsPurchase = 1
    BEGIN
        INSERT INTO [inventory].[PurchaseReturns]
            (ReturnNumber, ReturnDate, InvoiceId, WarehouseId, Description, TotalAmount, Status, CompanyId, FiscalYearId, CreatedBy)
        VALUES (N'', @ReturnDate, @InvoiceId, @WarehouseId, @Description, 0, N'Posted', @CompanyId, @FiscalYearId, @CreatedBy);
        DECLARE @PurchaseReturnId INT = SCOPE_IDENTITY();
        DECLARE @ReturnNumber NVARCHAR(50) = N'PRET-' + RIGHT(N'00000' + CAST(@PurchaseReturnId AS NVARCHAR(10)), 5);
        UPDATE [inventory].[PurchaseReturns] SET ReturnNumber = @ReturnNumber WHERE PurchaseReturnId = @PurchaseReturnId;
    END
    ELSE
    BEGIN
        INSERT INTO [inventory].[SalesReturns]
            (ReturnNumber, ReturnDate, InvoiceId, WarehouseId, Description, TotalAmount, Status, CompanyId, FiscalYearId, CreatedBy)
        VALUES (N'', @ReturnDate, @InvoiceId, @WarehouseId, @Description, 0, N'Posted', @CompanyId, @FiscalYearId, @CreatedBy);
        DECLARE @SalesReturnId INT = SCOPE_IDENTITY();
        SET @ReturnNumber = N'SRET-' + RIGHT(N'00000' + CAST(@SalesReturnId AS NVARCHAR(10)), 5);
        UPDATE [inventory].[SalesReturns] SET ReturnNumber = @ReturnNumber WHERE SalesReturnId = @SalesReturnId;
    END

    -- Process lines
    DECLARE @InvLineId INT, @Qty DECIMAL(18,3);
    DECLARE @ItemId INT, @UnitPrice DECIMAL(18,2), @LineNet DECIMAL(18,2);
    DECLARE @TotalReturn DECIMAL(18,2) = 0;

    DECLARE curLine CURSOR LOCAL FAST_FORWARD FOR
        SELECT [InvoiceLineId], [Qty] FROM OPENJSON(@LinesJson) WITH (InvoiceLineId INT, Qty DECIMAL(18,3));
    OPEN curLine;
    FETCH NEXT FROM curLine INTO @InvLineId, @Qty;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @IsPurchase = 1
        BEGIN
            SELECT @ItemId = ItemId, @UnitPrice = UnitPrice, @LineNet = NetAmount
            FROM [inventory].[InvoiceLines] WHERE InvoiceLineId = @InvLineId;
            -- Check returnable qty (purchased - already returned)
            DECLARE @PurchasedQty DECIMAL(18,3) = (SELECT Qty FROM [inventory].[InvoiceLines] WHERE InvoiceLineId = @InvLineId);
            DECLARE @AlreadyReturned DECIMAL(18,3) = ISNULL((
                SELECT SUM(rl.Qty) FROM [inventory].[PurchaseReturnLines] rl
                WHERE rl.InvoiceLineId = @InvLineId), 0);
            IF @Qty > (@PurchasedQty - @AlreadyReturned)
                THROW 51070, N'مقدار برگشت بیشتر از مقدار قابل برگشت است.', 1;

            INSERT INTO [inventory].[PurchaseReturnLines] (PurchaseReturnId, InvoiceLineId, ItemId, Qty, UnitPrice, NetAmount)
            VALUES (@PurchaseReturnId, @InvLineId, @ItemId, @Qty, @UnitPrice, ROUND(@Qty * @UnitPrice, 2));

            -- Return to inventory (Issue = stock out, since goods go back to supplier)
            INSERT INTO [inventory].[Movements]
                (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
            VALUES (N'', N'Issue', @ItemId, @WarehouseId, @Qty, @UnitPrice, @UnitPrice, @ReturnDate,
                    N'برگشت خرید ' + @ReturnNumber, N'Posted', @CreatedBy, @CompanyId);
        END
        ELSE
        BEGIN
            SELECT @ItemId = ItemId, @UnitPrice = UnitPrice, @LineNet = NetAmount
            FROM [inventory].[InvoiceLines] WHERE InvoiceLineId = @InvLineId;
            DECLARE @SoldQty DECIMAL(18,3) = (SELECT Qty FROM [inventory].[InvoiceLines] WHERE InvoiceLineId = @InvLineId);
            DECLARE @AlreadyRet DECIMAL(18,3) = ISNULL((
                SELECT SUM(rl.Qty) FROM [inventory].[SalesReturnLines] rl
                WHERE rl.InvoiceLineId = @InvLineId), 0);
            IF @Qty > (@SoldQty - @AlreadyRet)
                THROW 51071, N'مقدار برگشت بیشتر از مقدار قابل برگشت است.', 1;

            INSERT INTO [inventory].[SalesReturnLines] (SalesReturnId, InvoiceLineId, ItemId, Qty, UnitPrice, NetAmount)
            VALUES (@SalesReturnId, @InvLineId, @ItemId, @Qty, @UnitPrice, ROUND(@Qty * @UnitPrice, 2));

            -- Return to inventory (Receipt = stock in, goods come back from customer)
            INSERT INTO [inventory].[Movements]
                (MovementNumber, MovementType, ItemId, WarehouseId, Qty, UnitPrice, CostPrice, MovementDate, Description, Status, CreatedBy, CompanyId)
            VALUES (N'', N'Receipt', @ItemId, @WarehouseId, @Qty, @UnitPrice, @UnitPrice, @ReturnDate,
                    N'برگشت فروش ' + @ReturnNumber, N'Posted', @CreatedBy, @CompanyId);
        END

        DECLARE @LineTotal DECIMAL(18,2) = ROUND(@Qty * @UnitPrice, 2);
        SET @TotalReturn = @TotalReturn + @LineTotal;

        -- Update stock
        IF @IsPurchase = 1
            UPDATE [inventory].[Items] SET StockQty = StockQty - @Qty, UpdatedAt = SYSUTCDATETIME() WHERE ItemId = @ItemId AND CompanyId = @CompanyId;
        ELSE
            UPDATE [inventory].[Items] SET StockQty = StockQty + @Qty, UpdatedAt = SYSUTCDATETIME() WHERE ItemId = @ItemId AND CompanyId = @CompanyId;

        FETCH NEXT FROM curLine INTO @InvLineId, @Qty;
    END
    CLOSE curLine; DEALLOCATE curLine;

    -- Update return total
    IF @IsPurchase = 1
        UPDATE [inventory].[PurchaseReturns] SET TotalAmount = @TotalReturn WHERE PurchaseReturnId = @PurchaseReturnId;
    ELSE
        UPDATE [inventory].[SalesReturns] SET TotalAmount = @TotalReturn WHERE SalesReturnId = @SalesReturnId;

COMMIT;
SELECT
    CASE WHEN @IsPurchase = 1 THEN @PurchaseReturnId ELSE @SalesReturnId END AS ReturnId,
    @ReturnNumber AS ReturnNumber, @TotalReturn AS TotalAmount;
