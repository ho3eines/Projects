-- =============================================
-- Sample gold invoice for TODAY using the REAL GoldInvoiceCreate.sql
-- via sqlcmd :r include.
-- Sells 2g of XAU-24 to the company's first party, paid via bank.
-- Requires sample-gold-receipt.sql to have run first (FIFO layers).
--
-- Execute via: bash tools/seed-demo-data.sh
-- (it provides CompanyId / FiscalYearId via sqlcmd -v; requires -I flag).
-- =============================================
SET NOCOUNT ON;

DECLARE @CompanyId INT = $(CompanyId);
DECLARE @FiscalYearId INT = $(FiscalYearId);
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @InvoiceDate DATETIME2 = @Today;
DECLARE @PartyId INT = (SELECT TOP 1 PartyId FROM [central].[Parties] WHERE CompanyId = $(CompanyId) AND IsDeleted = 0 ORDER BY PartyId);
DECLARE @LinesJson NVARCHAR(MAX) = N'[
  {"RowType":"Gold","ItemCode":"XAU-24","Title":"طلای ۲۴ عیار (گرم)","Qty":2,"Price":38000000,"Workmanship":0,"Profit":1000000,"TaxEnabled":1}
]';
DECLARE @PayCash DECIMAL(18,2) = 0;
DECLARE @PayBank DECIMAL(18,2) = 79000000;
DECLARE @ChequeNumber NVARCHAR(50) = N'';
DECLARE @ChequeAmount DECIMAL(18,2) = 0;
DECLARE @ChequeBankId INT = NULL;
DECLARE @ChequeDueDate DATE = NULL;
DECLARE @PayCurrencyCode NVARCHAR(10) = N'';
DECLARE @PayCurrencyQty DECIMAL(18,4) = 0;
DECLARE @PayCurrencyRate DECIMAL(18,4) = 0;
DECLARE @PayGoldGram DECIMAL(18,4) = 0;
DECLARE @CreditType NVARCHAR(10) = N'Cash';
DECLARE @CreatedBy NVARCHAR(100) = N'seed';
:r Tarazin.Data/Scripts/goldshop/GoldInvoiceCreate.sql
PRINT N'Gold invoice inserted.';
GO
