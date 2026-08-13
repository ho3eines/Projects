-- =============================================
-- Tarazin.Data/Scripts/bi/BiGoldKpis.sql
-- Schema: bi
-- Cross-schema: currency, goldshop
-- Query. داشبورد تخصصی طلا (§40–§43): ارزش/وزن/طلای خالص/تفکیک عیار/سود.
-- خروجی: ردیف‌های KPI با مقایسهٔ ارزش روز قبل (اسنپ‌شات ارز).
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);

-- ارزش/وزن طلا از دارایی فیزیکی (مرکز قیمت)
DECLARE @GoldValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
    WHERE p.ItemType = N'Gold'), 0);
DECLARE @CoinValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(r.SystemRate, 0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    LEFT JOIN [currency].[PriceRates] r ON r.PriceItemId = p.PriceItemId
    WHERE p.ItemType = N'Coin'), 0);
DECLARE @GoldWeight DECIMAL(18,3) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    WHERE p.ItemType = N'Gold'), 0);
-- طلای خالص معادل (وزن × عیار / ۲۴) — عیار از آیتم یا فرض ۱۸ برای آب‌شده/دست‌دوم
DECLARE @PureGold DECIMAL(18,3) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0) *
        CASE p.ItemKey
            WHEN N'XAU-24' THEN 24.0
            WHEN N'XAU-18' THEN 18.0
            WHEN N'XAU-20' THEN 20.0
            WHEN N'XAU-21' THEN 21.0
            WHEN N'XAU-22' THEN 22.0
            WHEN N'XAU-MELTED' THEN 18.0
            ELSE 18.0 END / 24.0)
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    WHERE p.ItemType = N'Gold'), 0);
-- ارزش بر اساس نرخ خرید (CostRate) و سود/زیان تغییر قیمت (§43)
DECLARE @GoldCostValue DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(h.Quantity, 0) * ISNULL(h.CostRate, 0))
    FROM [currency].[AssetHoldings] h
    JOIN [currency].[PriceItems] p ON p.ItemKey = h.ItemKey
    WHERE p.ItemType = N'Gold'), 0);
DECLARE @GoldPnl DECIMAL(18,2) = @GoldValue - @GoldCostValue;

-- سود معاملات طلا/سکه (محقق‌شده) در ماه جاری
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @GoldTradePnl DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.RealizedPnl, 0))
    FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE t.TransactionDate >= @MonthStart AND l.LegType IN (N'Gold', N'Coin', N'Metal')), 0);
-- وزن فروخته‌شدهٔ طلا در ماه (فاکتورهای طلافروشی)
DECLARE @GoldSoldWeight DECIMAL(18,3) = ISNULL((
    SELECT SUM(ISNULL(WeightGram, 0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0);

-- ارزش دیروز از اسنپ‌شات ارز (بخش طلا)
DECLARE @GoldValueYesterday DECIMAL(18,2) = ISNULL((
    SELECT GoldPart FROM [currency].[AssetValuationHistory] WHERE SnapshotDate = @Yesterday), 0);

SELECT N'gold_value' AS KpiKey, N'ارزش کل طلا (بازار)' AS Title, ISNULL(@GoldValue, 0) AS Amount, ISNULL(@GoldValueYesterday, 0) AS PrevAmount,
       @GoldValue - ISNULL(@GoldValueYesterday, 0) AS Change,
       CASE WHEN ISNULL(@GoldValueYesterday, 0) <> 0 THEN (@GoldValue - @GoldValueYesterday) * 100.0 / @GoldValueYesterday ELSE NULL END AS ChangePercent,
       N'IRR' AS Unit, N'/currency/assets' AS Link, N'∑ (مقدار × نرخ سیستم) دارایی‌های طلا' AS Formula, N'currency' AS Source
UNION ALL SELECT N'coin_value', N'ارزش سکه‌ها', ISNULL(@CoinValue, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'∑ (مقدار × نرخ سیستم) سکه‌ها', N'currency'
UNION ALL SELECT N'gold_weight', N'وزن کل طلا', ISNULL(@GoldWeight, 0), NULL, NULL, NULL, N'گرم', N'/currency/assets', N'∑ وزن دارایی‌های طلا', N'currency'
UNION ALL SELECT N'pure_gold', N'طلای خالص معادل (۲۴ عیار)', ISNULL(@PureGold, 0), NULL, NULL, NULL, N'گرم', N'/currency/assets', N'∑ وزن × عیار ÷ ۲۴', N'currency'
UNION ALL SELECT N'gold_cost_value', N'ارزش به نرخ خرید', ISNULL(@GoldCostValue, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'∑ (مقدار × نرخ خرید)', N'currency'
UNION ALL SELECT N'gold_pnl', N'سود/زیان تغییر قیمت طلا', ISNULL(@GoldPnl, 0), NULL, NULL, NULL, N'IRR', N'/currency/assets', N'ارزش بازار − ارزش به نرخ خرید', N'currency'
UNION ALL SELECT N'gold_trade_pnl_month', N'سود معاملات طلا/سکه (ماه)', ISNULL(@GoldTradePnl, 0), NULL, NULL, NULL, N'IRR', N'/currency/reports', N'جمع سود محقق‌شدهٔ پاهای طلا/سکه/فلز', N'currency'
UNION ALL SELECT N'gold_sold_weight_month', N'وزن طلای فروخته‌شده (ماه)', ISNULL(@GoldSoldWeight, 0), NULL, NULL, NULL, N'گرم', N'/goldshop/reports', N'جمع وزن فاکتورهای طلافروشی', N'goldshop';
