-- =============================================
-- Tarazin.Data/Scripts/goldshop/GoldInvoicePrint.sql
-- Schema: goldshop (Cross: central, treasury, currency, accounting)
-- Query. دادهٔ چاپ یک فاکتور طلافروشی (فروش/خرید) — برای ساخت گزارش Stimulsoft.
-- یک result set خروجی می‌دهد: هر ردیف = یک ردیف فاکتور؛ فیلدهای سرصفحه و تسویه
-- روی همهٔ ردیف‌ها تکرار می‌شوند تا گزارش فرمی یک‌جا از همان داده ساخته شود
-- (BiReportService خروجی Dapper به DataTable می‌کند).
-- @InvoiceId: شناسه فاکتور در goldshop.SaleInvoices
-- =============================================

IF NOT EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId)
    THROW 51098, N'فاکتور یافت نشد.', 1;

DECLARE @InvNum NVARCHAR(50)=(SELECT InvoiceNumber FROM [goldshop].[SaleInvoices] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId);
DECLARE @InvType NVARCHAR(10)=CASE WHEN @InvNum LIKE N'GPUR-%' THEN N'Purchase' ELSE N'Sale' END;

DECLARE @TaxPct DECIMAL(9,4)=ISNULL((SELECT DefaultTaxPercent FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId),10);
DECLARE @LaborTaxPct DECIMAL(9,4)=ISNULL((SELECT LaborTaxPercent FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@CompanyId),@TaxPct);

-- جمع پایه / مالیات / کل
DECLARE @TotalBase DECIMAL(18,2)=ISNULL((SELECT SUM(LineBase) FROM [goldshop].[InvoiceLines] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId),0);
DECLARE @TotalTax DECIMAL(18,2)=ISNULL((SELECT SUM(LineTax) FROM [goldshop].[InvoiceLines] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId),0);

-- طلا: نرخ میانگین قلم طلا (مثل GoldInvoiceCreate) و گرمِ تحویلی تسویه
DECLARE @GoldQty DECIMAL(18,4)=ISNULL((SELECT SUM(Qty) FROM [goldshop].[InvoiceLines] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId AND RowType=N'Gold'),0);
DECLARE @GoldPrice DECIMAL(18,2)=CASE WHEN @GoldQty>0
    THEN ROUND((SELECT SUM(Qty*Price)/@GoldQty FROM [goldshop].[InvoiceLines] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId AND RowType=N'Gold'),0)
    ELSE 0 END;

-- تسویه: نقدی/بانک از خزانه، چک از خزانه (+ عنوان بانک)، ارز از ماژول ارز،
-- طلای تحویلی و باقیمانده از دفتر طرف‌حساب.
DECLARE @PayCash DECIMAL(18,2)=ISNULL((SELECT SUM(cm.Amount) FROM [treasury].[CashMovements] cm WHERE cm.CompanyId=@CompanyId AND cm.SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId) AND cm.CashBoxId IS NOT NULL),0);
DECLARE @PayBank DECIMAL(18,2)=ISNULL((SELECT SUM(cm.Amount) FROM [treasury].[CashMovements] cm WHERE cm.CompanyId=@CompanyId AND cm.SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId) AND cm.AccountId IS NOT NULL),0);

SELECT
    s.InvoiceId,
    s.InvoiceNumber,
    s.InvoiceDate,
    @InvType AS InvoiceType,
    ISNULL(s.CustomerName, N'') AS PartyName,
    link.DetailAccountCode AS DetailCode,
    l.RowType,
    l.Title,
    CASE WHEN l.RowType=N'Currency' THEN l.ItemCode ELSE NULL END AS CurrencyCode,
    l.Qty,
    l.Price,
    l.Rate,
    l.Workmanship,
    l.Profit,
    l.TaxEnabled,
    l.LineBase,
    l.LineTax,
    l.LineTotal,
    -- خلاصهٔ مالی (روی همهٔ ردیف‌ها تکرار می‌شود)
    @TotalBase AS TotalBase,
    @TotalTax AS TotalTax,
    s.TotalAmount,
    ISNULL(s.TotalAmount -
        ( @PayCash
        + @PayBank
        + ISNULL((SELECT SUM(CreditGoldGram) FROM [goldshop].[GoldPartyLedger] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId),0)*@GoldPrice
        + ISNULL((SELECT SUM(Quantity) FROM [currency].[CurrencyMovements] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId) AND Direction=N'In'),0)
            * ISNULL((SELECT MAX(Rate) FROM [currency].[CurrencyMovements] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId) AND Direction=N'In'),0)
        + ISNULL((SELECT Amount FROM [treasury].[Cheques] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId)),0)
        ),0) AS BalanceRial,
    @TaxPct AS TaxPct,
    @LaborTaxPct AS LaborTaxPct,
    -- سند حسابداری
    ISNULL((SELECT TOP 1 d.DocumentId
            FROM [accounting].[Documents] d
            INNER JOIN [accounting].[DocumentLines] dl ON dl.DocumentId=d.DocumentId
            WHERE d.CompanyId=@CompanyId AND d.IsDeleted=0 AND dl.Description LIKE N'%'+s.InvoiceNumber+N'%'),0) AS DocumentId,
    -- تسویهٔ نقدی/بانک
    @PayCash AS PayCash,
    @PayBank AS PayBank,
    -- چک
    ISNULL((SELECT Amount FROM [treasury].[Cheques] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId)),0) AS PayChequeAmount,
    ISNULL((SELECT ChequeNumber FROM [treasury].[Cheques] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId)),N'') AS ChequeNumber,
    ISNULL((SELECT b.Title FROM [treasury].[Cheques] c LEFT JOIN [treasury].[Banks] b ON b.BankId=c.BankId WHERE c.CompanyId=@CompanyId AND c.SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId)),N'') AS ChequeBankName,
    (SELECT DueDate FROM [treasury].[Cheques] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GoldInvoice:',@InvoiceId)) AS ChequeDueDate,
    -- تسویه با طلا
    ISNULL((SELECT SUM(CreditGoldGram) FROM [goldshop].[GoldPartyLedger] WHERE InvoiceId=@InvoiceId AND CompanyId=@CompanyId),0) AS PayGoldGram,
    @GoldPrice AS GoldPrice,
    -- تسویه با ارز
    ISNULL((SELECT MAX(CurrencyCode) FROM [currency].[CurrencyMovements] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId) AND Direction=N'In'),N'') AS PayCurrencyCode,
    ISNULL((SELECT SUM(Quantity) FROM [currency].[CurrencyMovements] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId) AND Direction=N'In'),0) AS PayCurrencyQty,
    ISNULL((SELECT MAX(Rate) FROM [currency].[CurrencyMovements] WHERE CompanyId=@CompanyId AND SourceReference=CONCAT(N'GOLDINV:',@InvoiceId) AND Direction=N'In'),0) AS PayCurrencyRate
FROM [goldshop].[SaleInvoices] s
INNER JOIN [goldshop].[InvoiceLines] l ON l.InvoiceId=s.InvoiceId AND l.CompanyId=s.CompanyId
LEFT JOIN [treasury].[PartyLinks] link ON link.CompanyId=s.CompanyId AND link.PartyId=s.PartyId
WHERE s.InvoiceId=@InvoiceId AND s.CompanyId=@CompanyId
ORDER BY l.LineId;