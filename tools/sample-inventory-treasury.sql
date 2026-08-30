-- =============================================
-- Sample inventory + treasury data (dev DB only).
-- Runs the REAL project scripts (MovementInsert / CashMovementInsert /
-- ChequeInsert) via sqlcmd :r include, so the exact production insert
-- path is exercised.
--
-- Execute via: bash tools/seed-demo-data.sh
-- (it provides CompanyId / FiscalYearId via sqlcmd -v; requires -I flag).
--
-- Dates = TODAY so the default Home filters show rows.
-- InventorySettings.IsEnabled is temporarily disabled because its accounts
-- may be NULL (auto accounting doc would throw 51038); restored at the end.
-- TreasurySettings enabled + complete -> auto accounting docs are created.
-- =============================================
SET NOCOUNT ON;

-- Temporarily disable inventory auto-accounting (accounts may be NULL in this DB)
UPDATE inventory.InventorySettings SET IsEnabled = 0 WHERE CompanyId = $(CompanyId);

-- ── 1) Inventory Receipt: 100 g GOLD-18 into WH-01 ──
DECLARE @CompanyId INT = $(CompanyId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @ItemId INT = (SELECT TOP 1 ItemId FROM inventory.Items WHERE CompanyId = $(CompanyId) AND ItemCode = N'GOLD-18' AND IsDeleted = 0);
DECLARE @WarehouseId INT = (SELECT TOP 1 WarehouseId FROM inventory.Warehouses WHERE CompanyId = $(CompanyId) AND WarehouseCode = N'WH-01' AND IsDeleted = 0);
DECLARE @SubWarehouseId INT = NULL;
DECLARE @MovementType NVARCHAR(30) = N'Receipt';
DECLARE @Qty DECIMAL(18,3) = 100;
DECLARE @UnitPrice DECIMAL(18,2) = 28500000;
DECLARE @MovementDate DATETIME2 = @Today;
DECLARE @Description NVARCHAR(500) = N'رسید نمونه: خرید طلای ۱۸ عیار برای تست UI';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
DECLARE @FiscalYearId INT = NULL;
:r Tarazin.Data/Scripts/inventory/MovementInsert.sql
PRINT N'1) Inventory receipt inserted.';
GO

-- ── 2) Inventory Issue: 10 g GOLD-18 out of WH-01 ──
DECLARE @CompanyId INT = $(CompanyId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @ItemId INT = (SELECT TOP 1 ItemId FROM inventory.Items WHERE CompanyId = $(CompanyId) AND ItemCode = N'GOLD-18' AND IsDeleted = 0);
DECLARE @WarehouseId INT = (SELECT TOP 1 WarehouseId FROM inventory.Warehouses WHERE CompanyId = $(CompanyId) AND WarehouseCode = N'WH-01' AND IsDeleted = 0);
DECLARE @SubWarehouseId INT = NULL;
DECLARE @MovementType NVARCHAR(30) = N'Issue';
DECLARE @Qty DECIMAL(18,3) = 10;
DECLARE @UnitPrice DECIMAL(18,2) = 28500000;
DECLARE @MovementDate DATETIME2 = @Today;
DECLARE @Description NVARCHAR(500) = N'حواله نمونه: فروش طلای ۱۸ عیار';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
DECLARE @FiscalYearId INT = NULL;
:r Tarazin.Data/Scripts/inventory/MovementInsert.sql
PRINT N'2) Inventory issue inserted.';
GO

-- ── 3) Treasury: cash receipt (In) into first cashbox ──
DECLARE @CompanyId INT = $(CompanyId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Direction NVARCHAR(10) = N'In';
DECLARE @MovementDate DATETIME2 = @Today;
DECLARE @Amount DECIMAL(18,2) = 150000000;
DECLARE @CurrencyCode NVARCHAR(10) = N'IRR';
DECLARE @AccountId INT = NULL;
DECLARE @CashBoxId INT = (SELECT TOP 1 CashBoxId FROM treasury.CashBoxes WHERE CompanyId = $(CompanyId) AND IsDeleted = 0 ORDER BY CashBoxId);
DECLARE @Description NVARCHAR(500) = N'دریافت نمونه: فروش نقدی';
DECLARE @SourceReference NVARCHAR(100) = N'';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
DECLARE @FiscalYearId INT = $(FiscalYearId);
DECLARE @PartyId INT = NULL;
:r Tarazin.Data/Scripts/treasury/CashMovementInsert.sql
PRINT N'3) Treasury receipt inserted.';
GO

-- ── 4) Treasury: bank payment (Out) from first bank account ──
DECLARE @CompanyId INT = $(CompanyId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Direction NVARCHAR(10) = N'Out';
DECLARE @MovementDate DATETIME2 = @Today;
DECLARE @Amount DECIMAL(18,2) = 45000000;
DECLARE @CurrencyCode NVARCHAR(10) = N'IRR';
DECLARE @AccountId INT = (SELECT TOP 1 AccountId FROM treasury.BankAccounts WHERE CompanyId = $(CompanyId) AND IsDeleted = 0 ORDER BY AccountId);
DECLARE @CashBoxId INT = NULL;
DECLARE @Description NVARCHAR(500) = N'پرداخت نمونه: تسویه بدهی تأمین‌کننده';
DECLARE @SourceReference NVARCHAR(100) = N'';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
DECLARE @FiscalYearId INT = $(FiscalYearId);
DECLARE @PartyId INT = NULL;
:r Tarazin.Data/Scripts/treasury/CashMovementInsert.sql
PRINT N'4) Treasury payment inserted.';
GO

-- ── 5) Cheque: incoming, due in 15 days ──
DECLARE @CompanyId INT = $(CompanyId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @ChequeNumber NVARCHAR(50) = N'CHQ-SAMPLE-001';
DECLARE @BankId INT = (SELECT TOP 1 BankId FROM treasury.Banks WHERE CompanyId = $(CompanyId) AND IsDeleted = 0 ORDER BY BankId);
DECLARE @Amount DECIMAL(18,2) = 60000000;
DECLARE @DueDate DATE = DATEADD(DAY, 15, @Today);
DECLARE @Direction NVARCHAR(10) = N'In';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
:r Tarazin.Data/Scripts/treasury/ChequeInsert.sql
PRINT N'5) Cheque inserted.';
GO

-- Restore inventory auto-accounting enabled flag (accounts still NULL; keep as it was)
UPDATE inventory.InventorySettings SET IsEnabled = 1 WHERE CompanyId = $(CompanyId);
PRINT N'Done.';
GO
