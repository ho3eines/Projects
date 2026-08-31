-- =============================================
-- Tarazin.Data/Scripts/inventory/SalesInvoiceInsert.sql
-- Schema: inventory
-- Cross-schema: accounting, central
-- Execute. ثبت فاکتور فروش + اقلام + حواله انبار (FIFO/LIFO/WA) + سند حسابداری.
--   الگو: PurchaseInvoiceInsert (معکوس) + OrderPlace (کنترل موجودی).
-- پارامترها:
--   @InvoiceDate, @CustomerPartyId, @WarehouseId, @SubWarehouseId, @ReferenceNumber,
--   @PaymentTerms, @DueDate, @SaleType, @Description, @CompanyId, @FiscalYearId, @CreatedBy
--   @LinesJson — JSON array: [{ ItemId, Qty, GiftQty, UnitPrice, DiscountPercent, TaxPercent, DutyPercent }]
-- =============================================
DECLARE @CustomerName NVARCHAR(200) = N'';
IF @CustomerPartyId IS NOT NULL
    SELECT @CustomerName = FullName FROM [central].[Parties] WHERE PartyId = @CustomerPartyId AND IsDeleted = 0;

IF @WarehouseId IS NULL
    THROW 51050, N'انبار فروش مشخص نشده است.', 1;

-- Parse lines
DECLARE @Lines TABLE (
    RowId           INT IDENTITY(1,1) PRIMARY KEY,
    ItemId          INT NOT NULL,
    Qty             DECIMAL(18,3) NOT NULL DEFAULT 0,
    GiftQty         DECIMAL(18,3) NOT NULL DEFAULT 0,
    UnitPrice       DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountPercent DECIMAL(5,2) NOT NULL DEFAULT 0,
    TaxPercent      DECIMAL(5,2) NOT NULL DEFAULT 0,
    DutyPercent     DECIMAL(5,2) NOT NULL DEFAULT 0,
    GrossAmount     DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountAmount  DECIMAL(18,2) NOT NULL DEFAULT 0,
    TaxAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    DutyAmount      DECIMAL(18,2) NOT NULL DEFAULT 0,
    NetAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    CostPrice       DECIMAL(18,2) NOT NULL DEFAULT 0,
    COGS            DECIMAL(18,2) NOT NULL DEFAULT 0   -- بهای تمام‌شده کالای فروش‌رفته
);

INSERT INTO @Lines (ItemId, Qty, GiftQty, UnitPrice, DiscountPercent, TaxPercent, DutyPercent)
SELECT [ItemId], [Qty], ISNULL([GiftQty], 0), [UnitPrice],
       ISNULL([DiscountPercent], 0), ISNULL([TaxPercent], 0), ISNULL([DutyPercent], 0)
FROM OPENJSON(@LinesJson)
WITH (ItemId INT, Qty DECIMAL(18,3), GiftQty DECIMAL(18,3), UnitPrice DECIMAL(18,2),
      DiscountPercent DECIMAL(5,2), TaxPercent DECIMAL(5,2), DutyPercent DECIMAL(5,2));

IF NOT EXISTS (SELECT 1 FROM @Lines)
    THROW 51051, N'اقلام فاکتور خالی است.', 1;

-- Line amounts
UPDATE l SET
    GrossAmount = l.Qty * l.UnitPrice,
    DiscountAmount = ROUND(l.Qty * l.UnitPrice * l.DiscountPercent / 100, 2),
    TaxAmount = ROUND((l.Qty * l.UnitPrice - l.DiscountAmount) * l.TaxPercent / 100, 2),
    DutyAmount = ROUND((l.Qty * l.UnitPrice - l.DiscountAmount) * l.DutyPercent / 100, 2),
    NetAmount = l.Qty * l.UnitPrice - l.DiscountAmount + l.TaxAmount + l.DutyAmount
FROM @Lines l;

-- Header totals
DECLARE @GrossAmount DECIMAL(18,2) = (SELECT SUM(GrossAmount) FROM @Lines);
DECLARE @DiscountTotal DECIMAL(18,2) = (SELECT SUM(DiscountAmount) FROM @Lines);
DECLARE @TaxTotal DECIMAL(18,2) = (SELECT SUM(TaxAmount) FROM @Lines);
DECLARE @DutyTotal DECIMAL(18,2) = (SELECT SUM(DutyAmount) FROM @Lines);
DECLARE @NetAmount DECIMAL(18,2) = @GrossAmount - @DiscountTotal + @TaxTotal + @DutyTotal;

-- Costing method
DECLARE @CostingMethod NVARCHAR(30) = ISNULL(
    (SELECT CostingMethod FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), N'WeightedAverage');

-- ── Stock check before transaction ──
DECLARE @Unavailable INT = 0;
SELECT @Unavailable = COUNT(*)
FROM @Lines l
JOIN [inventory].[Items] i ON i.ItemId = l.ItemId AND i.CompanyId = @CompanyId AND i.IsDeleted = 0
WHERE i.StockQty < l.Qty;
IF @Unavailable > 0
    THROW 51052, N'موجودی انبار برای یک یا چند کالای فاکتور فروش کافی نیست.', 1;

BEGIN TRAN;

    -- ── Invoice header ──
    INSERT INTO [inventory].[Invoices]
        (OperationType, InvoiceNumber, InvoiceDate, CustomerPartyId, CustomerName, WarehouseId, SubWarehouseId,
         ReferenceNumber, PaymentTerms, DueDate, SaleType, Description,
         GrossAmount, DiscountAmount, TaxAmount, DutyAmount, NetAmount,
         Status, CompanyId, FiscalYearId, CreatedBy)
    VALUES
        (N'Sales', N'', @InvoiceDate, @CustomerPartyId, @CustomerName, @WarehouseId, @SubWarehouseId,
         @ReferenceNumber, @PaymentTerms, @DueDate, @SaleType, @Description,
         @GrossAmount, @DiscountTotal, @TaxTotal, @DutyTotal, @NetAmount,
         N'Posted', @CompanyId, @FiscalYearId, @CreatedBy);
    DECLARE @SalesInvoiceId INT = SCOPE_IDENTITY();
    DECLARE @InvNumber NVARCHAR(50) = N'SINV-' + RIGHT(N'00000' + CAST(@SalesInvoiceId AS NVARCHAR(10)), 5);
    UPDATE [inventory].[Invoices] SET InvoiceNumber = @InvNumber WHERE InvoiceId = @SalesInvoiceId;

    -- ── Lines + inventory issue (per line) ──
    DECLARE @RowId INT, @ItemId INT, @Qty DECIMAL(18,3), @GiftQty DECIMAL(18,3);
    DECLARE @UnitPrice DECIMAL(18,2), @LineGross DECIMAL(18,2), @LineDisc DECIMAL(18,2);
    DECLARE @LineTax DECIMAL(18,2), @LineDuty DECIMAL(18,2), @LineNet DECIMAL(18,2);
    DECLARE @TotalCOGS DECIMAL(18,2) = 0;

    DECLARE curLine CURSOR LOCAL FAST_FORWARD FOR
        SELECT RowId, ItemId, Qty, GiftQty, UnitPrice, GrossAmount, DiscountAmount, TaxAmount, DutyAmount, NetAmount
        FROM @Lines ORDER BY RowId;
    OPEN curLine;
    FETCH NEXT FROM curLine INTO @RowId, @ItemId, @Qty, @GiftQty, @UnitPrice, @LineGross, @LineDisc, @LineTax, @LineDuty, @LineNet;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @IssueQty DECIMAL(18,3) = @Qty + @GiftQty;
        DECLARE @IssueCost DECIMAL(18,2) = 0;

        IF @CostingMethod = N'WeightedAverage'
        BEGIN
            SET @IssueCost = ISNULL((SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId), 0);
        END
        ELSE
        BEGIN
            -- FIFO/LIFO: consume stock layers
            DECLARE @RemQty DECIMAL(18,3) = @IssueQty, @TotCost DECIMAL(18,2) = 0;
            DECLARE @LyId INT, @LyCost DECIMAL(18,2), @LyRem DECIMAL(18,3);
            DECLARE curLayers CURSOR LOCAL FAST_FORWARD FOR
                SELECT LayerId, UnitCost, QtyRemaining FROM [inventory].[StockLayers]
                WHERE ItemId = @ItemId AND WarehouseId = @WarehouseId AND QtyRemaining > 0 AND CompanyId = @CompanyId
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
            SET @IssueCost = CASE WHEN @IssueQty > 0 THEN ROUND(@TotCost / @IssueQty, 2) ELSE 0 END;
        END

        DECLARE @LineCOGS DECIMAL(18,2) = ROUND(@IssueCost * @IssueQty, 2);
        SET @TotalCOGS = @TotalCOGS + @LineCOGS;

        INSERT INTO [inventory].[InvoiceLines]
            (InvoiceId, ItemId, Qty, GiftQty, UnitPrice, GrossAmount,
             DiscountPercent, DiscountAmount, TaxPercent, TaxAmount, DutyPercent, DutyAmount,
             ChargesAmount, CostPrice, NetAmount, SortOrder)
        VALUES
            (@SalesInvoiceId, @ItemId, @Qty, @GiftQty, @UnitPrice, @LineGross,
             (SELECT DiscountPercent FROM @Lines WHERE RowId = @RowId), @LineDisc,
             (SELECT TaxPercent FROM @Lines WHERE RowId = @RowId), @LineTax,
             (SELECT DutyPercent FROM @Lines WHERE RowId = @RowId), @LineDuty,
             0, @IssueCost, @LineNet, @RowId);

        -- Inventory issue movement
        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice,
             MovementDate, Description, Status, CreatedBy, CompanyId)
        VALUES
            (N'', N'Issue', @ItemId, @WarehouseId, @SubWarehouseId, @IssueQty, @UnitPrice, @IssueCost,
             @InvoiceDate, N'حواله بابت فاکتور فروش ' + @InvNumber, N'Posted', @CreatedBy, @CompanyId);
        DECLARE @Mid INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5) WHERE MovementId = @Mid;

        UPDATE [inventory].[Items] SET StockQty = StockQty - @IssueQty, UpdatedAt = SYSUTCDATETIME(), SalePrice = @UnitPrice
        WHERE ItemId = @ItemId AND CompanyId = @CompanyId;

        FETCH NEXT FROM curLine INTO @RowId, @ItemId, @Qty, @GiftQty, @UnitPrice, @LineGross, @LineDisc, @LineTax, @LineDuty, @LineNet;
    END
    CLOSE curLine; DEALLOCATE curLine;

    -- Gross profit
    DECLARE @GrossProfit DECIMAL(18,2) = @NetAmount - @TotalCOGS;
    UPDATE [inventory].[Invoices] SET CostOfGoodsSold = @TotalCOGS, GrossProfit = @GrossProfit WHERE InvoiceId = @SalesInvoiceId;

    -- ── Accounting document ──
    DECLARE @SettingsEnabled BIT = ISNULL((SELECT IsEnabled FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), 0);
    DECLARE @DocumentId INT = NULL;
    IF @SettingsEnabled = 1
    BEGIN
        IF @FiscalYearId IS NULL
            THROW 51027, N'سال مالی فعال برای ثبت سند حسابداری انتخاب نشده است.', 1;

        DECLARE @InvAccountId INT, @InvCode NVARCHAR(4000), @InvTitle NVARCHAR(200);
        DECLARE @ContraAccountId INT, @ContraCode NVARCHAR(4000), @ContraTitle NVARCHAR(200);
        SELECT @InvAccountId = InventoryAccountId, @InvCode = InventoryAccountCode, @InvTitle = InventoryAccountTitle,
               @ContraAccountId = IssueContraAccountId, @ContraCode = IssueContraAccountCode, @ContraTitle = IssueContraAccountTitle
        FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId;

        IF @InvAccountId IS NULL OR @ContraAccountId IS NULL
            THROW 51039, N'حساب‌های انبار/مقابل در تنظیمات انبار تنظیم نشده است.', 1;

        DECLARE @NextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber))
                                       FROM [accounting].[Documents]
                                       WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;

        INSERT INTO [accounting].[Documents]
            (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId, SourceReference)
        VALUES
            (RIGHT(N'00000000' + CAST(@NextNum AS NVARCHAR(10)), 8), @InvoiceDate, N'SalesInvoice', @CustomerName, @NetAmount, N'IRR', N'Note', @CreatedBy, 0, @CompanyId, @FiscalYearId, CONCAT(N'SalesInvoice:', @SalesInvoiceId));
        SET @DocumentId = SCOPE_IDENTITY();

        -- بدهکار: طرف حساب (مشتری) / بستانکار: فروش
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES (@DocumentId, @ContraAccountId, @ContraCode, @ContraTitle, N'بدهکار مشتری ' + @InvNumber, @NetAmount, 0);
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES (@DocumentId, @InvAccountId, @InvCode, @InvTitle, N'فروش ' + @InvNumber, 0, @NetAmount);

        -- COGS entry (دائمی): بدهکار بهای تمام‌شده / بستانکار موجودی
        IF @TotalCOGS > 0
        BEGIN
            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            VALUES (@DocumentId, @ContraAccountId, @ContraCode, @ContraTitle, N'بهای تمام‌شده فروش ' + @InvNumber, @TotalCOGS, 0);
            INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            VALUES (@DocumentId, @InvAccountId, @InvCode, @InvTitle, N'خروج موجودی ' + @InvNumber, 0, @TotalCOGS);
        END

        UPDATE [inventory].[Invoices] SET DocumentId = @DocumentId WHERE InvoiceId = @SalesInvoiceId;
    END

COMMIT;
SELECT @SalesInvoiceId AS SalesInvoiceId, @InvNumber AS InvoiceNumber, @NetAmount AS NetAmount,
       @TotalCOGS AS CostOfGoodsSold, @GrossProfit AS GrossProfit, @DocumentId AS DocumentId;
