DECLARE @InvoiceId INT=19;
DECLARE @CompanyId INT=3;
-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldInvoiceReverse.sql
-- Schema: goldshop (Cross: accounting, inventory, currency, treasury)
-- Execute. برگرداندن کامل یک فاکتور طلافروشی (فروش/خرید) و همهٔ عوارض
-- جانبی آن در یک تراکنش.
--
-- جداول دارای IsDeleted → soft-delete (Movements, Documents)
-- جداول فاقد IsDeleted → hard DELETE (SaleInvoices, InvoiceLines, GoldPartyLedger,
--   CurrencyMovements, CashMovements, DocumentLines, Cheques)
--
-- @InvoiceId: شناسه فاکتور در goldshop.SaleInvoices
-- =============================================

IF NOT EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId)
    THROW 51098, N'فاکتور یافت نشد.', 1;

DECLARE @InvNum NVARCHAR(50)=(SELECT InvoiceNumber FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId);
DECLARE @InvDate DATE=(SELECT InvoiceDate FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId);

BEGIN TRAN;

-- ۱) برگرداندن انبار
DECLARE @InvItemId INT,@InvWHId INT,@InvQty DECIMAL(18,4),@InvPrice DECIMAL(18,2),@MovementType NVARCHAR(20);
DECLARE curInv CURSOR LOCAL FAST_FORWARD FOR
    SELECT m.ItemId,m.WarehouseId,m.Qty,m.UnitPrice,m.MovementType
    FROM [inventory].[Movements] m
    WHERE m.CompanyId=@CompanyId AND m.Description LIKE N'%'+@InvNum+N'%'
      AND m.IsDeleted=0;
OPEN curInv;
FETCH NEXT FROM curInv INTO @InvItemId,@InvWHId,@InvQty,@InvPrice,@MovementType;
WHILE @@FETCH_STATUS=0
BEGIN
    IF @MovementType=N'Issue'
        UPDATE [inventory].[Items] SET StockQty=StockQty+@InvQty,UpdatedAt=SYSUTCDATETIME()
        WHERE ItemId=@InvItemId AND CompanyId=@CompanyId;
    ELSE IF @MovementType=N'Receipt'
        UPDATE [inventory].[Items] SET StockQty=StockQty-@InvQty,UpdatedAt=SYSUTCDATETIME()
        WHERE ItemId=@InvItemId AND CompanyId=@CompanyId;
    FETCH NEXT FROM curInv INTO @InvItemId,@InvWHId,@InvQty,@InvPrice,@MovementType;
END
CLOSE curInv; DEALLOCATE curInv;
-- Soft-delete (Movements has IsDeleted)
UPDATE [inventory].[Movements] SET IsDeleted=1,UpdatedAt=SYSUTCDATETIME()
WHERE CompanyId=@CompanyId AND Description LIKE N'%'+@InvNum+N'%' AND IsDeleted=0;

-- ۲) برگرداندن کیف پول ارز
DECLARE @FXD NVARCHAR(10),@FXC NVARCHAR(10),@FXQ DECIMAL(18,4),@FXR DECIMAL(18,4);
DECLARE curFx CURSOR LOCAL FAST_FORWARD FOR
    SELECT Direction,CurrencyCode,Quantity,Rate
    FROM [currency].[CurrencyMovements]
    WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId);
OPEN curFx;
FETCH NEXT FROM curFx INTO @FXD,@FXC,@FXQ,@FXR;
WHILE @@FETCH_STATUS=0
BEGIN
    IF @FXD=N'Out'
        UPDATE [currency].[Wallets]
        SET Quantity=Quantity+@FXQ,OutQty=OutQty-@FXQ,UpdatedAt=SYSUTCDATETIME()
        WHERE CurrencyCode=@FXC AND CompanyId=@CompanyId;
    ELSE IF @FXD=N'In'
        UPDATE [currency].[Wallets]
        SET Quantity=Quantity-@FXQ,InQty=InQty-@FXQ,UpdatedAt=SYSUTCDATETIME()
        WHERE CurrencyCode=@FXC AND CompanyId=@CompanyId;
    FETCH NEXT FROM curFx INTO @FXD,@FXC,@FXQ,@FXR;
END
CLOSE curFx; DEALLOCATE curFx;
-- Hard delete (CurrencyMovements has no IsDeleted)
DELETE FROM [currency].[CurrencyMovements]
WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId);

-- ۳) برگرداندن صندوق/بانک
DECLARE @CMDir NVARCHAR(10),@CMAmt DECIMAL(18,2),@CMBoxId INT,@CMAccId INT;
DECLARE curCM CURSOR LOCAL FAST_FORWARD FOR
    SELECT Direction,Amount,CashBoxId,AccountId
    FROM [treasury].[CashMovements]
    WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId);
OPEN curCM;
FETCH NEXT FROM curCM INTO @CMDir,@CMAmt,@CMBoxId,@CMAccId;
WHILE @@FETCH_STATUS=0
BEGIN
    IF @CMDir=N'In'
    BEGIN
        IF @CMBoxId IS NOT NULL
            UPDATE [treasury].[CashBoxes] SET Balance=Balance-@CMAmt WHERE CashBoxId=@CMBoxId AND CompanyId=@CompanyId;
        IF @CMAccId IS NOT NULL
            UPDATE [treasury].[BankAccounts] SET Balance=Balance-@CMAmt WHERE AccountId=@CMAccId AND CompanyId=@CompanyId;
    END
    FETCH NEXT FROM curCM INTO @CMDir,@CMAmt,@CMBoxId,@CMAccId;
END
CLOSE curCM; DEALLOCATE curCM;
-- Hard delete (CashMovements has no IsDeleted)
DELETE FROM [treasury].[CashMovements]
WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId);

-- ۴) برگرداندن چک — Void instead of delete (چک باطل می‌شود)
UPDATE [treasury].[Cheques]
SET Status=N'Voided',UpdatedAt=SYSUTCDATETIME()
WHERE CompanyId=@CompanyId AND Status=N'Pending'
  AND CreatedAt >= @InvDate AND CreatedAt < DATEADD(DAY,1,@InvDate)
  AND Direction=N'In'
  AND EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] s WHERE s.InvoiceId=@InvoiceId
              AND ABS(s.TotalAmount-Amount)<=s.TotalAmount*0.01);

-- ۵) برگرداندن سند حسابداری
DECLARE @DocId INT;
SELECT TOP 1 @DocId=d.DocumentId
FROM [accounting].[Documents] d
INNER JOIN [accounting].[DocumentLines] l ON l.DocumentId=d.DocumentId
WHERE d.CompanyId=@CompanyId AND d.IsDeleted=0
  AND l.Description LIKE N'%'+@InvNum+N'%';
-- Hard delete lines (DocumentLines has no IsDeleted)
DELETE FROM [accounting].[DocumentLines] WHERE DocumentId=@DocId;
-- Soft-delete header (Documents has IsDeleted)
UPDATE [accounting].[Documents] SET IsDeleted=1,UpdatedAt=SYSUTCDATETIME() WHERE DocumentId=@DocId AND IsDeleted=0;

-- ۶) دفتر طرف‌حساب — hard delete
DELETE FROM [goldshop].[GoldPartyLedger] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId;

-- ۷) ردیف‌های فاکتور — hard delete
DELETE FROM [goldshop].[InvoiceLines] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId;

-- ۸) سرصفحه فاکتور — hard delete
DELETE FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId;

COMMIT;
SELECT @InvoiceId AS InvoiceId,@InvNum AS InvoiceNumber;