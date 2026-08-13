-- =============================================
-- Tarazin.Data/Scripts/bi/BiReviewSummary.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency, treasury, accounting, inventory, central
-- Query. گزارش جامع یک دوره (§112–§114): فروش/سود/هزینه/نقدینگی/طلا/ارز/موجودی/مطالبات/بدهی/چک.
-- پارامترها: @FromDate و @ToDate (بازهٔ انتخابی — فیلتر سراسری §2).
-- خروجی: ردیف‌های KPI با مقدار دورهٔ انتخابی.
-- =============================================
DECLARE @From DATE = ISNULL(@FromDate, CAST(SYSDATETIME() AS DATE));
DECLARE @To DATE = ISNULL(@ToDate, CAST(SYSDATETIME() AS DATE));

DECLARE @Sales DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @From AND @To), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate BETWEEN @From AND @To AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate BETWEEN @From AND @To AND TransactionType = N'Sell'), 0);
DECLARE @Profit DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(Workmanship,0)+ISNULL(Profit,0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @From AND @To), 0)
    + ISNULL((SELECT SUM(ISNULL(l.RealizedPnl,0)) FROM [currency].[FxTransactionLegs] l JOIN [currency].[FxTransactions] t ON t.FxTransactionId=l.FxTransactionId WHERE t.TransactionDate BETWEEN @From AND @To), 0);
DECLARE @Expense DECIMAL(18,2) = ISNULL((SELECT SUM(l.Debit) FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate BETWEEN @From AND @To AND a.AccountType = N'Expense'), 0);
DECLARE @Receipts DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate BETWEEN @From AND @To AND Direction = N'In'), 0);
DECLARE @Payments DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate BETWEEN @From AND @To AND Direction = N'Out'), 0);
DECLARE @Liquidity DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0)
    + ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);
DECLARE @GoldValue DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(h.Quantity,0)*ISNULL(r.SystemRate,0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
    WHERE p.ItemType = N'Gold'), 0);
DECLARE @CoinValue DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(h.Quantity,0)*ISNULL(r.SystemRate,0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
    WHERE p.ItemType = N'Coin'), 0);
DECLARE @FxValue DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(w.Quantity,0)*ISNULL(r.SystemRate,0))
    FROM [currency].[Wallets] w
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0);
DECLARE @Inventory DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(StockQty,0)*ISNULL(UnitPrice,0)) FROM [inventory].[Items] WHERE IsDeleted = 0), 0);
DECLARE @Receivable DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(l.Debit,0)-ISNULL(l.Credit,0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Asset' AND a.IsDeleted = 0 AND a.AccountCode NOT IN (N'1000',N'1010',N'1020',N'1030',N'1040')), 0);
DECLARE @Payable DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(l.Credit,0)-ISNULL(l.Debit,0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Liability' AND a.IsDeleted = 0), 0);
DECLARE @Cheques30 DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques]
    WHERE Status = N'Pending' AND DueDate BETWEEN CAST(SYSDATETIME() AS DATE) AND DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE))), 0);
DECLARE @Customers INT = ISNULL((SELECT COUNT(*) FROM [central].[Parties] WHERE PartyType = N'Customer' AND IsDeleted = 0), 0);
DECLARE @PeriodLabel NVARCHAR(20) = FORMAT(@From, N'yyyy/MM') + N' تا ' + FORMAT(@To, N'yyyy/MM/dd');

SELECT N'rev_sales' AS KpiKey, N'فروش دوره (' + @PeriodLabel + N')' AS Title, ISNULL(@Sales, 0) AS Amount,
       NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent, N'IRR' AS Unit,
       N'/goldshop/reports' AS Link, N'طلا + فروشگاه + فروش ارز' AS Formula, N'multi' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'rev_profit', N'سود ناخالص دوره', ISNULL(@Profit, 0), NULL, NULL, NULL, N'IRR', N'/currency/dashboard', N'اجرت+سود طلا + سود ارز', N'goldshop/currency', N'Neutral'
UNION ALL SELECT N'rev_expense', N'هزینه دوره (دفتر کل)', ISNULL(@Expense, 0), NULL, NULL, NULL, N'IRR', N'/accounting/reports', N'بدهکار حساب‌های هزینه', N'accounting', N'Neutral'
UNION ALL SELECT N'rev_receipts', N'دریافت‌های دوره', ISNULL(@Receipts, 0), NULL, NULL, NULL, N'IRR', N'/treasury/reports', N'جریان نقدی ورودی', N'treasury', N'Neutral'
UNION ALL SELECT N'rev_payments', N'پرداخت‌های دوره', ISNULL(@Payments, 0), NULL, NULL, NULL, N'IRR', N'/treasury/reports', N'جریان نقدی خروجی', N'treasury', N'Neutral'
UNION ALL SELECT N'rev_liquidity', N'نقدینگی فعلی', ISNULL(@Liquidity, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'بانک + صندوق', N'treasury', N'Neutral'
UNION ALL SELECT N'rev_gold', N'ارزش طلای موجود', ISNULL(@GoldValue, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'دارایی طلا × نرخ سیستم', N'currency', N'Neutral'
UNION ALL SELECT N'rev_coin', N'ارزش سکه‌ها', ISNULL(@CoinValue, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'دارایی سکه × نرخ سیستم', N'currency', N'Neutral'
UNION ALL SELECT N'rev_fx', N'ارزش ارزها', ISNULL(@FxValue, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'کیف پول‌ها × نرخ سیستم', N'currency', N'Neutral'
UNION ALL SELECT N'rev_inventory', N'ارزش موجودی کالا', ISNULL(@Inventory, 0), NULL, NULL, NULL, N'IRR', N'/inventory/reports', N'موجودی × قیمت واحد', N'inventory', N'Neutral'
UNION ALL SELECT N'rev_receivable', N'مطالبات', ISNULL(@Receivable, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=customers', N'ماندهٔ دارایی‌های غیرنقد', N'accounting', N'Neutral'
UNION ALL SELECT N'rev_payable', N'بدهی‌ها', ISNULL(@Payable, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=payables', N'ماندهٔ حساب‌های بدهکار', N'accounting', N'Neutral'
UNION ALL SELECT N'rev_cheques30', N'چک‌های ۳۰ روز آینده', ISNULL(@Cheques30, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'چک‌های Pending سررسید ۳۰ روز', N'treasury', N'Neutral'
UNION ALL SELECT N'rev_customers', N'تعداد مشتریان', ISNULL(@Customers, 0), NULL, NULL, NULL, N'مشتری', N'/central/users', N'اشخاص نوع Customer', N'central', N'Neutral';
