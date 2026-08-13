-- =============================================
-- Tarazin.Data/Scripts/bi/BiConversionStats.sql
-- Schema: bi
-- Cross-schema: currency, treasury
-- Query. تحلیل تبدیل ارز (§59): تعداد/حجم/کارمزد/سود + پرتکرارترین مبدا/مقصد.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

DECLARE @Count INT = ISNULL((SELECT COUNT(*) FROM [currency].[FxTransactions]
                             WHERE TransactionDate >= @MonthStart AND TransactionType = N'Conversion'), 0);
DECLARE @Volume DECIMAL(18,2) = ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions]
                                        WHERE TransactionDate >= @MonthStart AND TransactionType = N'Conversion'), 0);
DECLARE @Fee DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements]
                                     WHERE MovementDate >= @MonthStart AND Description LIKE N'%کارمزد تبدیل%'), 0);
DECLARE @Pnl DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(l.RealizedPnl, 0))
                                     FROM [currency].[FxTransactionLegs] l
                                     JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
                                     WHERE t.TransactionDate >= @MonthStart AND t.TransactionType = N'Conversion'), 0);
DECLARE @TopSource NVARCHAR(50) = ISNULL((
    SELECT TOP 1 l.ItemKey FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE t.TransactionDate >= @MonthStart AND t.TransactionType = N'Conversion' AND l.Direction = N'Out'
    GROUP BY l.ItemKey ORDER BY COUNT(*) DESC), N'—');
DECLARE @TopTarget NVARCHAR(50) = ISNULL((
    SELECT TOP 1 l.ItemKey FROM [currency].[FxTransactionLegs] l
    JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
    WHERE t.TransactionDate >= @MonthStart AND t.TransactionType = N'Conversion' AND l.Direction = N'In'
    GROUP BY l.ItemKey ORDER BY COUNT(*) DESC), N'—');

SELECT N'conv_count' AS KpiKey, N'تعداد تبدیل (ماه)' AS Title, ISNULL(@Count, 0) AS Amount,
       NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent, N'عملیات' AS Unit,
       N'/currency/reports' AS Link, N'تعداد معاملات Conversion' AS Formula, N'currency' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'conv_volume', N'حجم تبدیل (ماه)', ISNULL(@Volume, 0), NULL, NULL, NULL, N'IRR', N'/currency/reports', N'جمع ریالی تبدیل‌ها', N'currency', N'Neutral'
UNION ALL SELECT N'conv_fee', N'کارمزد تبدیل (ماه)', ISNULL(@Fee, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'کارمزدهای ثبت‌شده در خزانه', N'treasury', N'Neutral'
UNION ALL SELECT N'conv_pnl', N'سود تبدیل (ماه)', ISNULL(@Pnl, 0), NULL, NULL, NULL, N'IRR', N'/currency/reports', N'سود/زیان محقق‌شدهٔ پاهای تبدیل', N'currency', N'Neutral'
UNION ALL SELECT N'conv_top_source', N'پرتکرارترین ارز مبدا', (SELECT COUNT(*) FROM [currency].[FxTransactionLegs] l
         JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
         WHERE t.TransactionDate >= @MonthStart AND t.TransactionType = N'Conversion' AND l.Direction = N'Out' AND l.ItemKey = @TopSource),
       NULL, NULL, NULL, @TopSource, N'/currency/reports', N'ارز با بیشترین خروج در تبدیل', N'currency', N'Neutral'
UNION ALL SELECT N'conv_top_target', N'پرتکرارترین ارز مقصد', (SELECT COUNT(*) FROM [currency].[FxTransactionLegs] l
         JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId
         WHERE t.TransactionDate >= @MonthStart AND t.TransactionType = N'Conversion' AND l.Direction = N'In' AND l.ItemKey = @TopTarget),
       NULL, NULL, NULL, @TopTarget, N'/currency/reports', N'ارز با بیشترین ورود در تبدیل', N'currency', N'Neutral';
