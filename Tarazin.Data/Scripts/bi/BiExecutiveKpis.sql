-- =============================================
-- Tarazin.Data/Scripts/bi/BiExecutiveKpis.sql
-- Schema: bi
-- Cross-schema: accounting, treasury, currency, goldshop, store, inventory, central
-- Query. KPIهای سطح ۱ — Executive Dashboard (§4): فروش/سود/نقد/مطالبات/بدهی/دارایی/مشتری
-- با مقایسهٔ دورهٔ قبل (امروز/دیروز، ماه/ماه قبل، سال/سال قبل — §3).
-- خروجی: ردیف‌های (KpiKey, Title, Amount, PrevAmount, Change, ChangePercent, Direction, Status, Unit, Link)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);
DECLARE @YearStart DATE = DATEFROMPARTS(YEAR(@Today), 1, 1);
DECLARE @PrevYearStart DATE = DATEFROMPARTS(YEAR(@Today) - 1, 1, 1);
DECLARE @PrevYearEnd DATE = DATEADD(DAY, -1, @YearStart);

-- ── فروش ترکیبی: طلافروشی + فروشگاه (Invoiced) + فروش ارز (Sell) ──────────
DECLARE @SalesToday DECIMAL(18,2), @SalesYesterday DECIMAL(18,2);
DECLARE @SalesMonth DECIMAL(18,2), @SalesPrevMonth DECIMAL(18,2);
DECLARE @SalesYear DECIMAL(18,2), @SalesPrevYear DECIMAL(18,2);

SELECT @SalesToday = ISNULL(SUM(Amt), 0) FROM (
    SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = @Today
    UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate = @Today AND Status = N'Invoiced'
    UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate = @Today AND TransactionType = N'Sell') s;

SELECT @SalesYesterday = ISNULL(SUM(Amt), 0) FROM (
    SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = @Yesterday
    UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate = @Yesterday AND Status = N'Invoiced'
    UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate = @Yesterday AND TransactionType = N'Sell') s;

SELECT @SalesMonth = ISNULL(SUM(Amt), 0) FROM (
    SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart
    UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate >= @MonthStart AND Status = N'Invoiced'
    UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell') s;

SELECT @SalesPrevMonth = ISNULL(SUM(Amt), 0) FROM (
    SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @PrevMonthStart AND @PrevMonthEnd
    UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND Status = N'Invoiced'
    UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND TransactionType = N'Sell') s;

SELECT @SalesYear = ISNULL(SUM(Amt), 0) FROM (
    SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @YearStart
    UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate >= @YearStart AND Status = N'Invoiced'
    UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate >= @YearStart AND TransactionType = N'Sell') s;

SELECT @SalesPrevYear = ISNULL(SUM(Amt), 0) FROM (
    SELECT TotalAmount AS Amt FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @PrevYearStart AND @PrevYearEnd
    UNION ALL SELECT TotalAmount FROM [store].[Orders] WHERE OrderDate BETWEEN @PrevYearStart AND @PrevYearEnd AND Status = N'Invoiced'
    UNION ALL SELECT TotalRial FROM [currency].[FxTransactions] WHERE TransactionDate BETWEEN @PrevYearStart AND @PrevYearEnd AND TransactionType = N'Sell') s;

-- ── سود: اجرت+سود فاکتورهای طلا + سود محقق‌شدهٔ ارز (§53) ──────────────────
DECLARE @ProfitMonth DECIMAL(18,2), @ProfitPrevMonth DECIMAL(18,2);
DECLARE @ProfitYear DECIMAL(18,2);
SELECT @ProfitMonth = ISNULL((SELECT SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)) FROM [goldshop].[SaleInvoices]
                              WHERE InvoiceDate >= @MonthStart), 0)
                    + ISNULL((SELECT SUM(ISNULL(RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l
                              JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
                              WHERE t.TransactionDate >= @MonthStart), 0);
SELECT @ProfitPrevMonth = ISNULL((SELECT SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)) FROM [goldshop].[SaleInvoices]
                                  WHERE InvoiceDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0)
                        + ISNULL((SELECT SUM(ISNULL(RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l
                                  JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
                                  WHERE t.TransactionDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0);
SELECT @ProfitYear = ISNULL((SELECT SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)) FROM [goldshop].[SaleInvoices]
                             WHERE InvoiceDate >= @YearStart), 0)
                   + ISNULL((SELECT SUM(ISNULL(RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l
                             JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
                             WHERE t.TransactionDate >= @YearStart), 0);

-- ── نقد: بانک + صندوق ────────────────────────────────────────────────────
DECLARE @BankTotal DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0);
DECLARE @CashTotal DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);

-- ── مطالبات/بدهی از دفتر کل (اسناد واقعی) ─────────────────────────────────
DECLARE @Receivable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Debit, 0) - ISNULL(l.Credit, 0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Asset' AND a.IsDeleted = 0
      AND a.AccountCode NOT IN (N'1000', N'1010', N'1020', N'1030', N'1040')), 0);
DECLARE @Payable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Credit, 0) - ISNULL(l.Debit, 0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Liability' AND a.IsDeleted = 0), 0);

-- ── ارزش دارایی‌ها (نقد + ارز + طلا/سکه + کالا + مطالبات) به ریال (§12) ──
DECLARE @CurrencyValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[Wallets] w
    LEFT JOIN [currency].[PriceRates] r
        ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0);
DECLARE @GoldValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId), 0);
DECLARE @InventoryValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(StockQty, 0) * ISNULL(UnitPrice, 0)) FROM [inventory].[Items] WHERE IsDeleted = 0), 0);
DECLARE @AssetTotal DECIMAL(18,2) = @BankTotal + @CashTotal + @CurrencyValue + @GoldValue + @InventoryValue + @Receivable;

-- ── مشتریان و فاکتورها ────────────────────────────────────────────────────
DECLARE @CustomerCount INT = ISNULL((SELECT COUNT(*) FROM [central].[Parties]
                                     WHERE PartyType = N'Customer' AND IsDeleted = 0), 0);
DECLARE @NewCustomersMonth INT = ISNULL((SELECT COUNT(*) FROM [central].[Parties]
                                         WHERE PartyType = N'Customer' AND IsDeleted = 0
                                           AND CreatedAt >= @MonthStart), 0);
DECLARE @InvoicesToday INT = ISNULL((SELECT COUNT(*) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = @Today), 0)
                           + ISNULL((SELECT COUNT(*) FROM [store].[Orders] WHERE OrderDate = @Today), 0);
DECLARE @InvoicesMonth INT = ISNULL((SELECT COUNT(*) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0)
                           + ISNULL((SELECT COUNT(*) FROM [store].[Orders] WHERE OrderDate >= @MonthStart), 0);

-- ── خروجی ─────────────────────────────────────────────────────────────────
SELECT N'sales_today' AS KpiKey, N'فروش امروز' AS Title, ISNULL(@SalesToday, 0) AS Amount, ISNULL(@SalesYesterday, 0) AS PrevAmount,
       @SalesToday - @SalesYesterday AS Change,
       CASE WHEN ISNULL(@SalesYesterday, 0) <> 0 THEN (@SalesToday - @SalesYesterday) * 100.0 / @SalesYesterday ELSE NULL END AS ChangePercent,
       N'IRR' AS Unit, N'/goldshop' AS Link, N'جمع فاکتورهای طلا + سفارش‌های فروشگاه + فروش ارز' AS Formula, N'goldshop/store/currency' AS Source
UNION ALL SELECT N'sales_month', N'فروش ماه', @SalesMonth, @SalesPrevMonth, @SalesMonth - @SalesPrevMonth,
       CASE WHEN ISNULL(@SalesPrevMonth, 0) <> 0 THEN (@SalesMonth - @SalesPrevMonth) * 100.0 / @SalesPrevMonth ELSE NULL END,
       N'IRR', N'/goldshop/reports', N'جمع فروش از ابتدای ماه جاری', N'goldshop/store/currency'
UNION ALL SELECT N'sales_year', N'فروش سال', @SalesYear, @SalesPrevYear, @SalesYear - @SalesPrevYear,
       CASE WHEN ISNULL(@SalesPrevYear, 0) <> 0 THEN (@SalesYear - @SalesPrevYear) * 100.0 / @SalesPrevYear ELSE NULL END,
       N'IRR', N'/goldshop/reports', N'جمع فروش از ابتدای سال جاری', N'goldshop/store/currency'
UNION ALL SELECT N'gross_profit_month', N'سود ناخالص ماه', ISNULL(@ProfitMonth, 0), ISNULL(@ProfitPrevMonth, 0),
       @ProfitMonth - @ProfitPrevMonth,
       CASE WHEN ISNULL(@ProfitPrevMonth, 0) <> 0 THEN (@ProfitMonth - @ProfitPrevMonth) * 100.0 / @ProfitPrevMonth ELSE NULL END,
       N'IRR', N'/currency/dashboard', N'اجرت+سود فاکتور طلا + سود محقق‌شدهٔ ارز (§53)', N'goldshop/currency'
UNION ALL SELECT N'gross_profit_year', N'سود ناخالص سال', ISNULL(@ProfitYear, 0), NULL, NULL, NULL, N'IRR', N'/currency/dashboard', N'اجرت+سود طلا + سود ارز از ابتدای سال', N'goldshop/currency'
UNION ALL SELECT N'bank_total', N'موجودی بانک', ISNULL(@BankTotal, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'جمع ماندهٔ حساب‌های بانکی', N'treasury'
UNION ALL SELECT N'cash_total', N'موجودی صندوق', ISNULL(@CashTotal, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'جمع ماندهٔ صندوق‌ها', N'treasury'
UNION ALL SELECT N'receivable', N'مطالبات', ISNULL(@Receivable, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=customers', N'ماندهٔ حساب‌های دارایی غیرنقد (دفتر کل)', N'accounting'
UNION ALL SELECT N'payable', N'بدهی‌ها', ISNULL(@Payable, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=payables', N'ماندهٔ حساب‌های بدهکار (دفتر کل)', N'accounting'
UNION ALL SELECT N'inventory_value', N'ارزش موجودی کالا', ISNULL(@InventoryValue, 0), NULL, NULL, NULL, N'IRR', N'/inventory/reports', N'جمع (موجودی × قیمت واحد) کالاها', N'inventory'
UNION ALL SELECT N'asset_total', N'ارزش کل دارایی‌ها', ISNULL(@AssetTotal, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'نقد + ارز + طلا + کالا + مطالبات (به ریال)', N'multi'
UNION ALL SELECT N'customers_total', N'تعداد مشتریان', ISNULL(@CustomerCount, 0), NULL, NULL, NULL, N'عدد', N'/central/users', N'تعداد اشخاص نوع Customer', N'central'
UNION ALL SELECT N'customers_new_month', N'مشتریان جدید ماه', ISNULL(@NewCustomersMonth, 0), NULL, NULL, NULL, N'عدد', N'/central/users', N'مشتریان ساخته‌شده در ماه جاری', N'central'
UNION ALL SELECT N'invoices_today', N'فاکتورهای امروز', ISNULL(@InvoicesToday, 0), NULL, NULL, NULL, N'فاکتور', N'/goldshop', N'فاکتور طلا + سفارش فروشگاه امروز', N'goldshop/store'
UNION ALL SELECT N'invoices_month', N'فاکتورهای ماه', ISNULL(@InvoicesMonth, 0), NULL, NULL, NULL, N'فاکتور', N'/goldshop/reports', N'فاکتورهای ماه جاری', N'goldshop/store'
UNION ALL SELECT N'purchase_month', N'خرید ماه (اسناد خرید)', ISNULL((
       SELECT SUM(TotalAmount) FROM [accounting].[Documents]
       WHERE DocumentType = N'Purchase' AND IsDeleted = 0 AND DocumentDate >= @MonthStart), 0),
       NULL, NULL, NULL, N'IRR', N'/accounting', N'جمع اسناد خرید دفتر کل', N'accounting'
UNION ALL SELECT N'gross_margin', N'حاشیه سود ناخالص', 
       CASE WHEN ISNULL(@SalesMonth, 0) = 0 THEN 0 ELSE ROUND(@ProfitMonth * 100.0 / @SalesMonth, 2) END,
       NULL, NULL, NULL, N'٪', N'/currency/dashboard', N'سود ناخالص ماه ÷ فروش ماه (§7)', N'goldshop/currency'
UNION ALL SELECT N'net_margin', N'حاشیه سود خالص',
       CASE WHEN ISNULL(@SalesMonth, 0) = 0 THEN 0 ELSE ROUND(ISNULL((
           SELECT SUM(CASE WHEN a.AccountType = N'Income' THEN l.Credit ELSE -l.Debit END)
           FROM [accounting].[DocumentLines] l
           JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
           JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
           WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate >= @MonthStart
             AND a.AccountType IN (N'Income', N'Expense')), 0) * 100.0 / @SalesMonth, 2) END,
       NULL, NULL, NULL, N'٪', N'/accounting/reports', N'سود خالص دفتر کل ÷ فروش ماه (§7)', N'accounting';
