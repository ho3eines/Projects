SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;

-- The complete goldshop schema is maintained in the startup script.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'goldshop') EXEC(N'CREATE SCHEMA [goldshop]');
IF OBJECT_ID(N'goldshop.GoldItems',N'U') IS NULL    CREATE TABLE [goldshop].[GoldItems](GoldItemId INT IDENTITY PRIMARY KEY,ItemCode NVARCHAR(50) NOT NULL,Title NVARCHAR(200) NOT NULL,Purity DECIMAL(5,2) NULL,IsActive BIT NOT NULL DEFAULT 1,IsDeleted BIT NOT NULL DEFAULT 0,CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
IF OBJECT_ID(N'goldshop.GoldPrices',N'U') IS NULL
CREATE TABLE [goldshop].[GoldPrices](PriceId INT IDENTITY PRIMARY KEY,ItemCode NVARCHAR(50) NOT NULL,Title NVARCHAR(200) NOT NULL,PricePerGram DECIMAL(18,0) NOT NULL DEFAULT 0,RateToIRR DECIMAL(18,0) NULL,IsDeleted BIT NOT NULL DEFAULT 0,UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
IF OBJECT_ID(N'goldshop.SaleInvoices',N'U') IS NULL
CREATE TABLE [goldshop].[SaleInvoices](InvoiceId INT IDENTITY PRIMARY KEY,InvoiceNumber NVARCHAR(50) NOT NULL,InvoiceDate DATE NOT NULL,CustomerName NVARCHAR(200) NULL,ItemCode NVARCHAR(50) NOT NULL,WeightGram DECIMAL(18,3) NOT NULL DEFAULT 0,Workmanship DECIMAL(18,0) NOT NULL DEFAULT 0,Profit DECIMAL(18,0) NOT NULL DEFAULT 0,Tax DECIMAL(18,0) NOT NULL DEFAULT 0,TotalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,Status NVARCHAR(30) NOT NULL DEFAULT N'Issued',CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),CreatedBy NVARCHAR(100) NULL);
IF OBJECT_ID(N'goldshop.InvoiceLines',N'U') IS NULL
CREATE TABLE [goldshop].[InvoiceLines](LineId BIGINT IDENTITY PRIMARY KEY,CompanyId INT NOT NULL,InvoiceId INT NOT NULL,RowType NVARCHAR(20) NOT NULL,ItemCode NVARCHAR(50) NULL,Title NVARCHAR(200) NOT NULL,Qty DECIMAL(18,4) NOT NULL DEFAULT 0,Price DECIMAL(18,2) NOT NULL DEFAULT 0,Rate DECIMAL(24,6) NULL,Workmanship DECIMAL(18,2) NOT NULL DEFAULT 0,Profit DECIMAL(18,2) NOT NULL DEFAULT 0,TaxEnabled BIT NOT NULL DEFAULT 0,LineBase DECIMAL(18,2) NOT NULL DEFAULT 0,LineTax DECIMAL(18,2) NOT NULL DEFAULT 0,LineTotal DECIMAL(18,2) NOT NULL DEFAULT 0);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_InvoiceLines_Invoice' AND object_id=OBJECT_ID(N'goldshop.InvoiceLines')) CREATE INDEX IX_InvoiceLines_Invoice ON [goldshop].[InvoiceLines](CompanyId,InvoiceId);
IF OBJECT_ID(N'goldshop.InventorySnapshot',N'U') IS NULL
CREATE TABLE [goldshop].[InventorySnapshot](SnapshotId INT IDENTITY PRIMARY KEY,MovementId INT NOT NULL UNIQUE,ItemCode NVARCHAR(50) NOT NULL,MovementType NVARCHAR(30) NOT NULL,Qty DECIMAL(18,3) NOT NULL DEFAULT 0,UnitPrice DECIMAL(18,2) NOT NULL DEFAULT 0,MovementDate DATE NOT NULL,CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
IF OBJECT_ID(N'goldshop.Outbox',N'U') IS NULL
CREATE TABLE [goldshop].[Outbox](OutboxId BIGINT IDENTITY PRIMARY KEY,EventType NVARCHAR(100) NOT NULL,EventKey NVARCHAR(200) NOT NULL,Payload NVARCHAR(MAX) NOT NULL,PayloadVersion INT NOT NULL DEFAULT 1,CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),ProcessedAt DATETIME2 NULL,Attempts INT NOT NULL DEFAULT 0,LastError NVARCHAR(MAX) NULL);

IF COL_LENGTH(N'goldshop.GoldItems',N'CompanyId') IS NULL ALTER TABLE [goldshop].[GoldItems] ADD CompanyId INT NULL;
IF COL_LENGTH(N'goldshop.GoldItems',N'InventoryItemCode') IS NULL ALTER TABLE [goldshop].[GoldItems] ADD InventoryItemCode NVARCHAR(50) NULL;
IF COL_LENGTH(N'goldshop.GoldItems',N'UpdatedAt') IS NULL ALTER TABLE [goldshop].[GoldItems] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'goldshop.GoldItems',N'CreatedBy') IS NULL ALTER TABLE [goldshop].[GoldItems] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.GoldItems',N'UpdatedBy') IS NULL ALTER TABLE [goldshop].[GoldItems] ADD UpdatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.GoldPrices',N'CompanyId') IS NULL ALTER TABLE [goldshop].[GoldPrices] ADD CompanyId INT NULL;
IF COL_LENGTH(N'goldshop.GoldPrices',N'CreatedAt') IS NULL ALTER TABLE [goldshop].[GoldPrices] ADD CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_GoldPrices_CreatedAt DEFAULT SYSUTCDATETIME();
IF COL_LENGTH(N'goldshop.GoldPrices',N'CreatedBy') IS NULL ALTER TABLE [goldshop].[GoldPrices] ADD CreatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.GoldPrices',N'UpdatedBy') IS NULL ALTER TABLE [goldshop].[GoldPrices] ADD UpdatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices',N'CompanyId') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD CompanyId INT NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices',N'PartyId') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD PartyId INT NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices',N'CurrencyCode') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD CurrencyCode NVARCHAR(10) NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices',N'PaymentStatus') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD PaymentStatus NVARCHAR(30) NOT NULL CONSTRAINT DF_GoldSaleInvoices_PaymentStatus DEFAULT N'Unpaid';
IF COL_LENGTH(N'goldshop.SaleInvoices',N'UpdatedAt') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD UpdatedAt DATETIME2 NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices',N'UpdatedBy') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD UpdatedBy NVARCHAR(100) NULL;
IF COL_LENGTH(N'goldshop.SaleInvoices',N'BranchId') IS NULL ALTER TABLE [goldshop].[SaleInvoices] ADD BranchId INT NULL;
IF COL_LENGTH(N'goldshop.InventorySnapshot',N'CompanyId') IS NULL ALTER TABLE [goldshop].[InventorySnapshot] ADD CompanyId INT NULL;

IF OBJECT_ID(N'goldshop.GoldShopSettings',N'U') IS NULL
CREATE TABLE [goldshop].[GoldShopSettings](CompanyId INT NOT NULL PRIMARY KEY,InventoryWarehouseId INT NULL,CustomerAccountGroupId INT NULL,SupplierAccountGroupId INT NULL,SalesAccountId INT NULL,InventoryAccountId INT NULL,TaxPayableAccountId INT NULL,CashAccountId INT NULL,BankAccountId INT NULL,CashBoxId INT NULL,BankChartAccountId INT NULL,DefaultTaxPercent DECIMAL(9,4) NOT NULL DEFAULT 10,LaborTaxPercent DECIMAL(9,4) NOT NULL DEFAULT 10,IsEnabled BIT NOT NULL DEFAULT 1,UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),UpdatedBy NVARCHAR(100) NULL);
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'CashBoxId') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD CashBoxId INT NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'BankChartAccountId') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD BankChartAccountId INT NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'InventoryAccountGroupId') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD InventoryAccountGroupId INT NULL;
-- AccountCode/Title مسیر کامل درخت جداول پایه (سازگار با DocumentInsert)
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'SalesAccountCode') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD SalesAccountCode NVARCHAR(4000) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'SalesAccountTitle') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD SalesAccountTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'InventoryAccountCode') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD InventoryAccountCode NVARCHAR(4000) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'InventoryAccountTitle') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD InventoryAccountTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'TaxPayableAccountCode') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD TaxPayableAccountCode NVARCHAR(4000) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'TaxPayableAccountTitle') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD TaxPayableAccountTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'CashAccountCode') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD CashAccountCode NVARCHAR(4000) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'CashAccountTitle') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD CashAccountTitle NVARCHAR(200) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'BankChartAccountCode') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD BankChartAccountCode NVARCHAR(4000) NULL;
IF COL_LENGTH(N'goldshop.GoldShopSettings',N'BankChartAccountTitle') IS NULL ALTER TABLE [goldshop].[GoldShopSettings] ADD BankChartAccountTitle NVARCHAR(200) NULL;
IF OBJECT_ID(N'goldshop.GoldPartyLedger',N'U') IS NULL
CREATE TABLE [goldshop].[GoldPartyLedger](LedgerId BIGINT IDENTITY PRIMARY KEY,CompanyId INT NOT NULL,PartyId INT NOT NULL,InvoiceId INT NULL,EntryDate DATE NOT NULL,EntryType NVARCHAR(30) NOT NULL,DebitRial DECIMAL(18,2) NOT NULL DEFAULT 0,CreditRial DECIMAL(18,2) NOT NULL DEFAULT 0,DebitGoldGram DECIMAL(18,3) NOT NULL DEFAULT 0,CreditGoldGram DECIMAL(18,3) NOT NULL DEFAULT 0,DebitCurrency DECIMAL(18,3) NOT NULL DEFAULT 0,CreditCurrency DECIMAL(18,3) NOT NULL DEFAULT 0,CurrencyCode NVARCHAR(10) NULL,Description NVARCHAR(500) NULL,CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),CreatedBy NVARCHAR(100) NULL);
IF OBJECT_ID(N'goldshop.GoldPartyLinks',N'U') IS NULL
CREATE TABLE [goldshop].[GoldPartyLinks](CompanyId INT NOT NULL,PartyId INT NOT NULL,PartyType NVARCHAR(30) NOT NULL,DetailLinkId INT NULL,DetailAccountCode NVARCHAR(50) NULL,CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),CreatedBy NVARCHAR(100) NULL,UpdatedAt DATETIME2 NULL,UpdatedBy NVARCHAR(100) NULL,CONSTRAINT PK_GoldPartyLinks PRIMARY KEY(CompanyId,PartyId));

DECLARE @Cid INT=(SELECT TOP 1 CompanyId FROM [central].[Companies] WHERE IsDeleted=0 ORDER BY CompanyId);
IF @Cid IS NOT NULL BEGIN
 UPDATE [goldshop].[GoldItems] SET CompanyId=@Cid WHERE CompanyId IS NULL;
 UPDATE [goldshop].[GoldPrices] SET CompanyId=@Cid WHERE CompanyId IS NULL;
 UPDATE [goldshop].[SaleInvoices] SET CompanyId=@Cid WHERE CompanyId IS NULL;
 UPDATE [goldshop].[InventorySnapshot] SET CompanyId=@Cid WHERE CompanyId IS NULL;
END
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'UX_GoldItems_Company_Code' AND object_id=OBJECT_ID(N'goldshop.GoldItems')) CREATE UNIQUE INDEX UX_GoldItems_Company_Code ON [goldshop].[GoldItems](CompanyId,ItemCode) WHERE IsDeleted=0 AND CompanyId IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'UX_GoldPrices_Company_Code' AND object_id=OBJECT_ID(N'goldshop.GoldPrices')) CREATE UNIQUE INDEX UX_GoldPrices_Company_Code ON [goldshop].[GoldPrices](CompanyId,ItemCode) WHERE IsDeleted=0 AND CompanyId IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_GoldPartyLedger_Party' AND object_id=OBJECT_ID(N'goldshop.GoldPartyLedger')) CREATE INDEX IX_GoldPartyLedger_Party ON [goldshop].[GoldPartyLedger](CompanyId,PartyId,EntryDate,LedgerId);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_GoldSaleInvoices_Party' AND object_id=OBJECT_ID(N'goldshop.SaleInvoices')) CREATE INDEX IX_GoldSaleInvoices_Party ON [goldshop].[SaleInvoices](CompanyId,PartyId,InvoiceDate);
GO
