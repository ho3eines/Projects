-- =============================================
-- Tarazin.Data/Scripts/bi/BiInsights.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency, treasury, inventory, accounting, central
-- Query. تحلیل هوشمند امروز (§103/§104) — جمله‌های تولیدشده از دادهٔ واقعی سیستم، نه متن ثابت.
-- خروجی: (InsightKey, Kind, Title, Detail, Link)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);

-- فروش امروز/دیروز
DECLARE @SalesToday DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = @Today), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate = @Today AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate = @Today AND TransactionType = N'Sell'), 0);
DECLARE @SalesYesterday DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate = @Yesterday), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate = @Yesterday AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate = @Yesterday AND TransactionType = N'Sell'), 0);

-- سود ماه/ماه قبل
DECLARE @ProfitMonth DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0)
    + ISNULL((SELECT SUM(ISNULL(l.RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId WHERE t.TransactionDate >= @MonthStart), 0);
DECLARE @ProfitPrev DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0)
    + ISNULL((SELECT SUM(ISNULL(l.RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId WHERE t.TransactionDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0);

-- نقدینگی و دارایی
DECLARE @Liquidity DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0)
    + ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);
DECLARE @GoldValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId), 0);
DECLARE @GoldValueYesterday DECIMAL(18,2) = ISNULL((SELECT GoldPart FROM [currency].[AssetValuationHistory] WHERE SnapshotDate = @Yesterday), 0);
DECLARE @FxValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[Wallets] w
    LEFT JOIN [currency].[PriceRates] r
        ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0);

-- بهترین شعبه: شعبه‌ای وجود ندارد → بهترین «کانال فروش» از دادهٔ واقعی
DECLARE @BestChannel NVARCHAR(200);
DECLARE @BestChannelAmt DECIMAL(18,2);
SELECT TOP 1 @BestChannel = Channel, @BestChannelAmt = Amt FROM (
    SELECT N'طلافروشی' AS Channel, ISNULL(SUM(TotalAmount), 0) AS Amt FROM [goldshop].[SaleInvoices]
    UNION ALL SELECT N'فروشگاه اینترنتی', ISNULL(SUM(TotalAmount), 0) FROM [store].[Orders] WHERE Status = N'Invoiced'
    UNION ALL SELECT N'فروش ارز', ISNULL(SUM(TotalRial), 0) FROM [currency].[FxTransactions] WHERE TransactionType = N'Sell'
) c ORDER BY Amt DESC;

-- چک‌های ۷ روز آینده
DECLARE @Cheque7 DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE DueDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) AND Status = N'Pending'), 0);

SELECT N'1' AS InsightKey, N'Info' AS Kind, N'فروش امروز',
       N'فروش امروز ' + FORMAT(@SalesToday, 'N0') + N' ریال است؛ نسبت به دیروز (' + FORMAT(@SalesYesterday, 'N0') + N') ' +
       CASE WHEN @SalesToday > @SalesYesterday THEN N'افزایش یافته است.' ELSE N'کاهش یافته است.' END,
       N'/goldshop/reports'
UNION ALL SELECT N'2', N'Info', N'سود ماه',
       N'سود ناخالص ماه جاری ' + FORMAT(@ProfitMonth, 'N0') + N' ریال است؛ ماه قبل ' + FORMAT(@ProfitPrev, 'N0') + N' بود.',
       N'/currency/dashboard'
UNION ALL SELECT N'3', N'Info', N'بهترین کانال فروش',
       N'بیشترین فروش از کانال «' + ISNULL(@BestChannel, N'—') + N'» با ' + FORMAT(ISNULL(@BestChannelAmt, 0), 'N0') + N' ریال است.',
       N'/bi?tab=sales'
UNION ALL SELECT N'4', N'Info', N'نقدینگی',
       N'نقدینگی قابل استفاده (بانک + صندوق) ' + FORMAT(@Liquidity, 'N0') + N' ریال است.',
       N'/treasury'
UNION ALL SELECT N'5', N'Info', N'ارزش طلا',
       N'ارزش طلای موجود ' + FORMAT(@GoldValue, 'N0') + N' ریال است؛ نسبت به دیروز (' + FORMAT(@GoldValueYesterday, 'N0') + N') ' +
       CASE WHEN @GoldValue > @GoldValueYesterday THEN N'افزایش یافته است.' ELSE N'کاهش یافته است.' END,
       N'/currency/assets'
UNION ALL SELECT N'6', N'Info', N'اثر ارز بر دارایی',
       N'ارزش ریالی کیف پول‌های ارز ' + FORMAT(@FxValue, 'N0') + N' ریال است.',
       N'/currency/wallets'
UNION ALL SELECT N'7', N'Info', N'چک‌های نزدیک سررسید',
       CASE WHEN ISNULL(@Cheque7, 0) = 0 THEN N'چکی در ۷ روز آینده سررسید نمی‌شود.'
            ELSE N'در مجموع ' + FORMAT(@Cheque7, 'N0') + N' ریال چک در ۷ روز آینده سررسید می‌شود.' END,
       N'/treasury'
UNION ALL SELECT N'8', N'Action', N'مشتری پرریسک',
       N'بزرگ‌ترین بدهکار را در داشبورد مشتریان ببینید و پیگیری وصول انجام دهید.',
       N'/bi?tab=customers'
UNION ALL SELECT N'9', N'Action', N'موجودی راکد',
       N'کالاهای راکد سرمایه را خوابانده‌اند — گزارش موجودی راکد را بررسی کنید.',
       N'/bi?tab=inventory';
