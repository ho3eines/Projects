-- =============================================
-- Tarazin.Data/Scripts/bi/BiCurrencyKpis.sql
-- Schema: bi
-- Cross-schema: currency
-- Query. داشبورد ارز (§54): موجودی ارزهای اصلی، ارزش ریالی، سود معاملات، سود/زیان نرخ.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

DECLARE @UsdQty DECIMAL(18,4) = ISNULL((SELECT Quantity FROM [currency].[Wallets] WHERE CurrencyCode = N'USD'), 0);
DECLARE @EurQty DECIMAL(18,4) = ISNULL((SELECT Quantity FROM [currency].[Wallets] WHERE CurrencyCode = N'EUR'), 0);
DECLARE @AedQty DECIMAL(18,4) = ISNULL((SELECT Quantity FROM [currency].[Wallets] WHERE CurrencyCode = N'AED'), 0);
DECLARE @OtherQty DECIMAL(18,4) = ISNULL((SELECT SUM(Quantity) FROM [currency].[Wallets] WHERE CurrencyCode NOT IN (N'USD', N'EUR', N'AED')), 0);
DECLARE @FxValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(w.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[Wallets] w
    LEFT JOIN [currency].[PriceRates] r
        ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0);
DECLARE @FxPnl DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(w.Quantity, 0) * (ISNULL(r.SystemRate, 0) - ISNULL(w.AvgBuyRate, ISNULL(r.SystemRate, 0))))
    FROM [currency].[Wallets] w
    LEFT JOIN [currency].[PriceRates] r
        ON r.PriceItemId = (SELECT PriceItemId FROM [currency].[PriceItems] WHERE ItemKey = w.CurrencyCode AND IsDeleted = 0)), 0);
DECLARE @FxTradePnlMonth DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.RealizedPnl, 0))
    FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE t.TransactionDate >= @MonthStart AND l.LegType = N'Currency'), 0);
DECLARE @FxBuyMonth DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(TotalRial, 0)) FROM [currency].[FxTransactions]
    WHERE TransactionDate >= @MonthStart AND TransactionType = N'Buy'), 0);
DECLARE @FxSellMonth DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(TotalRial, 0)) FROM [currency].[FxTransactions]
    WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell'), 0);
DECLARE @ConvertCountMonth INT = ISNULL((
    SELECT COUNT(*) FROM [currency].[FxTransactions]
    WHERE TransactionDate >= @MonthStart AND TransactionType = N'Conversion'), 0);

SELECT N'usd_qty' AS KpiKey, N'موجودی دلار' AS Title, ISNULL(@UsdQty, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'USD' AS Unit, N'/currency/wallets' AS Link, N'موجودی کیف پول دلار' AS Formula, N'currency' AS Source
UNION ALL SELECT N'eur_qty', N'موجودی یورو', ISNULL(@EurQty, 0), NULL, NULL, NULL, N'EUR', N'/currency/wallets', N'موجودی کیف پول یورو', N'currency'
UNION ALL SELECT N'aed_qty', N'موجودی درهم', ISNULL(@AedQty, 0), NULL, NULL, NULL, N'AED', N'/currency/wallets', N'موجودی کیف پول درهم', N'currency'
UNION ALL SELECT N'other_qty', N'موجودی سایر ارزها', ISNULL(@OtherQty, 0), NULL, NULL, NULL, N'واحد', N'/currency/wallets', N'مجموع سایر کیف پول‌ها', N'currency'
UNION ALL SELECT N'fx_value', N'ارزش ریالی کل ارز', ISNULL(@FxValue, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'∑ (موجودی × نرخ سیستم)', N'currency'
UNION ALL SELECT N'fx_pnl', N'سود/زیان تغییر نرخ ارز', ISNULL(@FxPnl, 0), NULL, NULL, NULL, N'IRR', N'/currency/dashboard', N'∑ موجودی × (نرخ جاری − متوسط خرید)', N'currency'
UNION ALL SELECT N'fx_trade_pnl_month', N'سود معاملات ارز (ماه)', ISNULL(@FxTradePnlMonth, 0), NULL, NULL, NULL, N'IRR', N'/currency/reports', N'جمع سود محقق‌شدهٔ پاهای ارز', N'currency'
UNION ALL SELECT N'fx_buy_month', N'خرید ارز (ماه)', ISNULL(@FxBuyMonth, 0), NULL, NULL, NULL, N'IRR', N'/currency/reports', N'مبلغ معاملات خرید ارز', N'currency'
UNION ALL SELECT N'fx_sell_month', N'فروش ارز (ماه)', ISNULL(@FxSellMonth, 0), NULL, NULL, NULL, N'IRR', N'/currency/reports', N'مبلغ معاملات فروش ارز', N'currency'
UNION ALL SELECT N'fx_convert_count_month', N'تعداد تبدیل ارز (ماه)', ISNULL(@ConvertCountMonth, 0), NULL, NULL, NULL, N'عملیات', N'/currency/reports', N'تعداد تبدیل‌های ثبت‌شده', N'currency';
