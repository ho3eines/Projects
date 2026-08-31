-- =============================================
-- Tarazin.Data/Scripts/inventory/PurchaseInvoiceInsert.sql
-- Schema: inventory
-- Cross-schema: accounting, central
-- Execute. ثبت فاکتور خرید + اقلام + رسید انبار + سند حسابداری.
--   الگو: MovementInsert + OrderPlace (transaction واحد، تراز صفر الزامی).
-- پارامترها:
--   @InvoiceDate, @SupplierPartyId, @WarehouseId, @SubWarehouseId, @ReferenceNumber,
--   @PaymentTerms, @DueDate, @Description, @CompanyId, @FiscalYearId, @CreatedBy
--   @LinesJson — JSON array: [{ ItemId, Qty, GiftQty, UnitPrice, DiscountPercent, TaxPercent, DutyPercent }]
-- =============================================
DECLARE @SupplierName NVARCHAR(200) = N'';
IF @SupplierPartyId IS NOT NULL
    SELECT @SupplierName = FullName FROM [central].[Parties] WHERE PartyId = @SupplierPartyId AND IsDeleted = 0;

IF @WarehouseId IS NULL
    THROW 51040, N'انبار مقصد فاکتور خرید مشخص نشده است.', 1;

-- Parse invoice lines from JSON
DECLARE @Lines TABLE (
    RowId         INT IDENTITY(1,1) PRIMARY KEY,
    ItemId        INT NOT NULL,
    Qty           DECIMAL(18,3) NOT NULL DEFAULT 0,
    GiftQty       DECIMAL(18,3) NOT NULL DEFAULT 0,
    UnitPrice     DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountPercent DECIMAL(5,2) NOT NULL DEFAULT 0,
    TaxPercent    DECIMAL(5,2) NOT NULL DEFAULT 0,
    DutyPercent   DECIMAL(5,2) NOT NULL DEFAULT 0,
    GrossAmount   DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    TaxAmount     DECIMAL(18,2) NOT NULL DEFAULT 0,
    DutyAmount    DECIMAL(18,2) NOT NULL DEFAULT 0,
    ChargesAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    CostPrice     DECIMAL(18,2) NOT NULL DEFAULT 0,
    NetAmount     DECIMAL(18,2) NOT NULL DEFAULT 0
);

INSERT INTO @Lines (ItemId, Qty, GiftQty, UnitPrice, DiscountPercent, TaxPercent, DutyPercent)
SELECT [ItemId], [Qty], ISNULL([GiftQty], 0), [UnitPrice],
       ISNULL([DiscountPercent], 0), ISNULL([TaxPercent], 0), ISNULL([DutyPercent], 0)
FROM OPENJSON(@LinesJson)
WITH (ItemId INT, Qty DECIMAL(18,3), GiftQty DECIMAL(18,3), UnitPrice DECIMAL(18,2),
      DiscountPercent DECIMAL(5,2), TaxPercent DECIMAL(5,2), DutyPercent DECIMAL(5,2));

IF NOT EXISTS (SELECT 1 FROM @Lines)
    THROW 51041, N'اقلام فاکتور خالی است.', 1;

-- Calculate line amounts
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

-- Costing method for inventory receipt
DECLARE @CostingMethod NVARCHAR(30) = ISNULL(
    (SELECT CostingMethod FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), N'WeightedAverage');

BEGIN TRAN;

    -- ── Invoice header ──
    INSERT INTO [inventory].[Invoices]
        (OperationType, InvoiceNumber, InvoiceDate, SupplierPartyId, SupplierName, WarehouseId, SubWarehouseId,
         ReferenceNumber, PaymentTerms, DueDate, Description,
         GrossAmount, DiscountAmount, TaxAmount, DutyAmount, NetAmount,
         Status, CompanyId, FiscalYearId, CreatedBy)
    VALUES
        (N'Purchase', N'', @InvoiceDate, @SupplierPartyId, @SupplierName, @WarehouseId, @SubWarehouseId,
         @ReferenceNumber, @PaymentTerms, @DueDate, @Description,
         @GrossAmount, @DiscountTotal, @TaxTotal, @DutyTotal, @NetAmount,
         N'Posted', @CompanyId, @FiscalYearId, @CreatedBy);
    DECLARE @PurchaseInvoiceId INT = SCOPE_IDENTITY();
    DECLARE @InvNumber NVARCHAR(50) = N'PINV-' + RIGHT(N'00000' + CAST(@PurchaseInvoiceId AS NVARCHAR(10)), 5);
    UPDATE [inventory].[Invoices] SET InvoiceNumber = @InvNumber WHERE InvoiceId = @PurchaseInvoiceId;

    -- ── Invoice lines + inventory receipt (per line) ──
    DECLARE @RowId INT, @ItemId INT, @Qty DECIMAL(18,3), @GiftQty DECIMAL(18,3), @UnitPrice DECIMAL(18,2);
    DECLARE @LineGross DECIMAL(18,2), @LineDisc DECIMAL(18,2), @LineTax DECIMAL(18,2), @LineDuty DECIMAL(18,2);
    DECLARE @LineCharges DECIMAL(18,2), @LineCost DECIMAL(18,2), @LineNet DECIMAL(18,2);

    DECLARE curLine CURSOR LOCAL FAST_FORWARD FOR
        SELECT RowId, ItemId, Qty, GiftQty, UnitPrice, GrossAmount, DiscountAmount, TaxAmount, DutyAmount, NetAmount
        FROM @Lines ORDER BY RowId;
    OPEN curLine;
    FETCH NEXT FROM curLine INTO @RowId, @ItemId, @Qty, @GiftQty, @UnitPrice, @LineGross, @LineDisc, @LineTax, @LineDuty, @LineNet;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Cost price: (net - tax - duty) / (qty + giftQty) — prorated charges
        SET @LineCharges = 0; -- per-line charges proration can be added later
        SET @LineCost = ROUND((@LineNet - @LineTax - @LineDuty) / NULLIF(@Qty + @GiftQty, 0), 2);

        INSERT INTO [inventory].[InvoiceLines]
            (InvoiceId, ItemId, Qty, GiftQty, UnitPrice, GrossAmount,
             DiscountPercent, DiscountAmount, TaxPercent, TaxAmount, DutyPercent, DutyAmount,
             ChargesAmount, CostPrice, NetAmount, SortOrder)
        VALUES
            (@PurchaseInvoiceId, @ItemId, @Qty, @GiftQty, @UnitPrice, @LineGross,
             (SELECT DiscountPercent FROM @Lines WHERE RowId = @RowId), @LineDisc,
             (SELECT TaxPercent FROM @Lines WHERE RowId = @RowId), @LineTax,
             (SELECT DutyPercent FROM @Lines WHERE RowId = @RowId), @LineDuty,
             @LineCharges, @LineCost, @LineNet, @RowId);

        -- ── Inventory receipt (Qty + GiftQty both enter stock) ──
        DECLARE @TotalReceiptQty DECIMAL(18,3) = @Qty + @GiftQty;
        INSERT INTO [inventory].[Movements]
            (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice,
             MovementDate, Description, Status, CreatedBy, CompanyId)
        VALUES
            (N'', N'Receipt', @ItemId, @WarehouseId, @SubWarehouseId, @TotalReceiptQty, @UnitPrice, @LineCost,
             @InvoiceDate, N'رسید بابت فاکتور خرید ' + @InvNumber, N'Posted', @CreatedBy, @CompanyId);
        DECLARE @Mid INT = SCOPE_IDENTITY();
        UPDATE [inventory].[Movements] SET MovementNumber = N'MV-' + RIGHT(N'00000' + CAST(@Mid AS NVARCHAR(10)), 5) WHERE MovementId = @Mid;

        -- Stock layer
        INSERT INTO [inventory].[StockLayers]
            (ItemId, WarehouseId, SubWarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
        VALUES
            (@ItemId, @WarehouseId, @SubWarehouseId, @Mid, @TotalReceiptQty, @LineCost, @InvoiceDate, @CompanyId);

        -- Update item stock + weighted average price
        IF @CostingMethod = N'WeightedAverage'
        BEGIN
            DECLARE @CurQty DECIMAL(18,3) = (SELECT StockQty FROM [inventory].[Items] WHERE ItemId = @ItemId);
            DECLARE @CurPrice DECIMAL(18,2) = (SELECT UnitPrice FROM [inventory].[Items] WHERE ItemId = @ItemId);
            IF @CurQty IS NULL OR @CurQty = 0 OR @CurPrice IS NULL OR @CurPrice = 0
                UPDATE [inventory].[Items] SET UnitPrice = @LineCost, PurchasePrice = @LineCost WHERE ItemId = @ItemId;
            ELSE
                UPDATE [inventory].[Items]
                SET UnitPrice = ROUND((@CurQty * @CurPrice + @TotalReceiptQty * @LineCost) / (@CurQty + @TotalReceiptQty), 2),
                    PurchasePrice = @LineCost
                WHERE ItemId = @ItemId;
        END

        UPDATE [inventory].[Items] SET StockQty = StockQty + @TotalReceiptQty, UpdatedAt = SYSUTCDATETIME()
        WHERE ItemId = @ItemId AND CompanyId = @CompanyId;

        FETCH NEXT FROM curLine INTO @RowId, @ItemId, @Qty, @GiftQty, @UnitPrice, @LineGross, @LineDisc, @LineTax, @LineDuty, @LineNet;
    END
    CLOSE curLine; DEALLOCATE curLine;

    -- ── Accounting document (if settings enabled) ──
    DECLARE @SettingsEnabled BIT = ISNULL((SELECT IsEnabled FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId), 0);
    IF @SettingsEnabled = 1
    BEGIN
        IF @FiscalYearId IS NULL
            THROW 51027, N'سال مالی فعال برای ثبت سند حسابداری انتخاب نشده است.', 1;

        DECLARE @InvAccountId INT, @InvCode NVARCHAR(4000), @InvTitle NVARCHAR(200);
        DECLARE @ContraAccountId INT, @ContraCode NVARCHAR(4000), @ContraTitle NVARCHAR(200);
        SELECT @InvAccountId = InventoryAccountId, @InvCode = InventoryAccountCode, @InvTitle = InventoryAccountTitle,
               @ContraAccountId = ReceiptContraAccountId, @ContraCode = ReceiptContraAccountCode, @ContraTitle = ReceiptContraAccountTitle
        FROM [inventory].[InventorySettings] WHERE CompanyId = @CompanyId;

        IF @InvAccountId IS NULL OR @ContraAccountId IS NULL
            THROW 51038, N'حساب‌های انبار/مقابل در تنظیمات انبار تنظیم نشده است.', 1;

        DECLARE @NextNum INT = ISNULL((SELECT MAX(TRY_CONVERT(INT, DocumentNumber))
                                       FROM [accounting].[Documents]
                                       WHERE CompanyId = @CompanyId AND FiscalYearId = @FiscalYearId AND IsDeleted = 0), 0) + 1;

        INSERT INTO [accounting].[Documents]
            (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId, SourceReference)
        VALUES
            (RIGHT(N'00000000' + CAST(@NextNum AS NVARCHAR(10)), 8), @InvoiceDate, N'PurchaseInvoice', @SupplierName, @NetAmount, N'IRR', N'Note', @CreatedBy, 0, @CompanyId, @FiscalYearId, CONCAT(N'PurchaseInvoice:', @PurchaseInvoiceId));
        DECLARE @DocumentId INT = SCOPE_IDENTITY();

        -- بدهکار: موجودی کالا / بستانکار: تأمین‌کننده
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES (@DocumentId, @InvAccountId, @InvCode, @InvTitle, N'خرید ' + @InvNumber, @NetAmount, 0);
        INSERT INTO [accounting].[DocumentLines] (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
        VALUES (@DocumentId, @ContraAccountId, @ContraCode, @ContraTitle, N'بستانکار تأمین‌کننده ' + @InvNumber, 0, @NetAmount);

        UPDATE [inventory].[Invoices] SET DocumentId = @DocumentId WHERE InvoiceId = @PurchaseInvoiceId;
    END

COMMIT;
SELECT @PurchaseInvoiceId AS PurchaseInvoiceId, @InvNumber AS InvoiceNumber, @NetAmount AS NetAmount, @DocumentId AS DocumentId;
