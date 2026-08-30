-- =============================================
-- Receipt GOLD-24 into the company's WH-01 warehouse so the gold invoice
-- has FIFO layers to consume. Must run BEFORE sample-gold-invoice.sql.
--
-- Execute via: bash tools/seed-demo-data.sh
-- (it provides CompanyId via sqlcmd -v; requires -I flag).
-- =============================================
SET NOCOUNT ON;

-- Temporarily disable inventory auto-accounting (accounts may be NULL in this DB)
UPDATE inventory.InventorySettings SET IsEnabled = 0 WHERE CompanyId = $(CompanyId);

-- Receipt: 50g GOLD-24 into WH-01
DECLARE @CompanyId INT = $(CompanyId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @ItemId INT = (SELECT TOP 1 ItemId FROM inventory.Items WHERE CompanyId = $(CompanyId) AND ItemCode = N'GOLD-24' AND IsDeleted = 0);
DECLARE @WarehouseId INT = (SELECT TOP 1 WarehouseId FROM inventory.Warehouses WHERE CompanyId = $(CompanyId) AND WarehouseCode = N'WH-01' AND IsDeleted = 0);
DECLARE @SubWarehouseId INT = NULL;
DECLARE @MovementType NVARCHAR(30) = N'Receipt';
DECLARE @Qty DECIMAL(18,3) = 50;
DECLARE @UnitPrice DECIMAL(18,2) = 38000000;
DECLARE @MovementDate DATETIME2 = @Today;
DECLARE @Description NVARCHAR(500) = N'رسید نمونه: خرید طلای ۲۴ عیار برای تست فروش';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
DECLARE @FiscalYearId INT = NULL;
:r Tarazin.Data/Scripts/inventory/MovementInsert.sql
PRINT N'GOLD-24 receipt inserted.';
GO

-- Restore
UPDATE inventory.InventorySettings SET IsEnabled = 1 WHERE CompanyId = $(CompanyId);
GO
