-- =============================================
-- seed-cleanup.sql — remove SAMPLE/demo artifacts ONLY (tools/sample-*.sql),
-- leaving the core _Seed.sql data intact.
--
-- Sample markers (only tools/sample-*.sql produce these):
--   * inventory.Movements   : Description LIKE N'%نمونه%' or N'%GINV-%'
--                             (the core _Seed.sql writes generic descriptions)
--   * treasury.CashMovements: Description LIKE N'%نمونه%' or
--                             SourceReference LIKE N'GoldInvoice:%'
--   * treasury.Cheques      : ChequeNumber LIKE N'CHQ-SAMPLE%'
--   * goldshop.SaleInvoices : rows that carry an InvoiceLine with
--                             ItemCode = N'XAU-24' (the sample sells XAU-24;
--                             core _Seed.sql only ever sells XAU-18)
--
-- Runs in FK-safe order and recomputes Items.StockQty from StockLayers
-- so seeds can re-run without duplicates or stale counts.
--
-- Execute via: bash tools/seed-demo-data.sh --reseed
-- =============================================
SET NOCOUNT ON;

DECLARE @CompanyId INT = $(CompanyId);

-- ── 0) Capture sample gold invoices (CreatedBy='seed' AND XAU-24 line) ──
DECLARE @SampleInvoices TABLE (InvoiceId INT PRIMARY KEY, InvoiceNumber NVARCHAR(50));
INSERT INTO @SampleInvoices (InvoiceId, InvoiceNumber)
SELECT DISTINCT i.InvoiceId, i.InvoiceNumber
FROM [goldshop].[SaleInvoices] i
INNER JOIN [goldshop].[InvoiceLines] l ON l.InvoiceId = i.InvoiceId AND l.ItemCode = N'XAU-24'
WHERE i.CompanyId = @CompanyId AND i.CreatedBy = N'seed';

-- ── 1) goldshop: lines + party ledger + invoice headers (hard delete) ──
DELETE FROM [goldshop].[InvoiceLines]    WHERE InvoiceId IN (SELECT InvoiceId FROM @SampleInvoices);
DELETE FROM [goldshop].[GoldPartyLedger] WHERE InvoiceId IN (SELECT InvoiceId FROM @SampleInvoices);
DELETE FROM [goldshop].[SaleInvoices]    WHERE InvoiceId IN (SELECT InvoiceId FROM @SampleInvoices);

-- ── 2) inventory movements made by the sample scripts (soft delete).
--      Captured BEFORE goldshop deletes because movements are the
--      gold invoice's inventory issue (حواله بابت GINV-xxxxx).
DECLARE @SampleMovements TABLE (MovementId INT PRIMARY KEY);
INSERT INTO @SampleMovements (MovementId)
SELECT MovementId
FROM [inventory].[Movements]
WHERE CompanyId = @CompanyId AND CreatedBy = N'seed'
  AND (Description LIKE N'%نمونه%' OR Description LIKE N'%GINV-%');

-- layers consumed by sample receipts (ReceiptMovementId FK) — drop them so
-- the re-seed receipt creates fresh FIFO layers (idempotent stock).
DELETE FROM [inventory].[StockLayers] WHERE ReceiptMovementId IN (SELECT MovementId FROM @SampleMovements);
UPDATE [inventory].[Movements] SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME()
WHERE MovementId IN (SELECT MovementId FROM @SampleMovements);

-- ── 3) currency movements created by those invoices (safety; sample uses none) ──
DELETE FROM [currency].[CurrencyMovements]
WHERE CompanyId = @CompanyId AND SourceReference LIKE N'GOLDINV:%';

-- ── 4) accounting documents of the sample gold invoice + seed cash docs
--      that mention GINV (docs + lines).
DECLARE @SampleDocs TABLE (DocumentId INT PRIMARY KEY);
INSERT INTO @SampleDocs (DocumentId)
SELECT d.DocumentId
FROM [accounting].[Documents] d
WHERE d.CompanyId = @CompanyId AND d.CreatedBy = N'seed'
  AND EXISTS (SELECT 1 FROM [accounting].[DocumentLines] dl
              WHERE dl.DocumentId = d.DocumentId
                AND (dl.Description LIKE N'%GINV-%' OR dl.Description LIKE N'%نمونه%'));

DELETE FROM [accounting].[DocumentLines] WHERE DocumentId IN (SELECT DocumentId FROM @SampleDocs);
UPDATE [accounting].[Documents] SET IsDeleted = 1, UpdatedAt = SYSUTCDATETIME()
WHERE DocumentId IN (SELECT DocumentId FROM @SampleDocs);

-- ── 5) treasury cash movements of the samples (restore balance, then delete) ──
DECLARE @SampleCash TABLE (Id INT PRIMARY KEY, Direction NVARCHAR(10), Amount DECIMAL(18,2), CashBoxId INT, AccountId INT);
INSERT INTO @SampleCash (Id, Direction, Amount, CashBoxId, AccountId)
SELECT MovementId, Direction, Amount, CashBoxId, AccountId
FROM [treasury].[CashMovements]
WHERE CompanyId = @CompanyId AND CreatedBy = N'seed'
  AND (Description LIKE N'%نمونه%' OR SourceReference LIKE N'GoldInvoice:%');

-- reverse of CashMovementInsert balance adjustment: In → subtract, Out → add
UPDATE cb SET cb.Balance = cb.Balance - CASE WHEN s.Direction=N'In' THEN s.Amount ELSE -s.Amount END
FROM [treasury].[CashBoxes] cb INNER JOIN @SampleCash s ON s.CashBoxId = cb.CashBoxId;
UPDATE ba SET ba.Balance = ba.Balance - CASE WHEN s.Direction=N'In' THEN s.Amount ELSE -s.Amount END
FROM [treasury].[BankAccounts] ba INNER JOIN @SampleCash s ON s.AccountId = ba.AccountId;

DELETE FROM [treasury].[CashMovements] WHERE MovementId IN (SELECT Id FROM @SampleCash);

-- ── 6) sample cheques (soft void) ──────────────────────────────────
UPDATE [treasury].[Cheques]
SET Status = N'Voided', UpdatedAt = SYSUTCDATETIME()
WHERE CompanyId = @CompanyId AND ChequeNumber LIKE N'CHQ-SAMPLE%' AND Status <> N'Voided';

-- ── 7) recompute Items.StockQty from remaining layers ──────────────
-- (single source of truth for FIFO stock after the cleanup above)
UPDATE it SET it.StockQty = ISNULL(l.Stock, 0), it.UpdatedAt = SYSUTCDATETIME()
FROM [inventory].[Items] it
LEFT JOIN (SELECT ItemId, SUM(QtyRemaining) AS Stock
           FROM [inventory].[StockLayers] WHERE CompanyId = @CompanyId
           GROUP BY ItemId) l ON l.ItemId = it.ItemId
WHERE it.CompanyId = @CompanyId;

PRINT N'Sample cleanup done for CompanyId=' + CAST(@CompanyId AS NVARCHAR(10)) + N'.';
GO