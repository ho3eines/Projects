-- =============================================
-- Tarazin.Data/Scripts/bi/BiTreasuryKpis.sql
-- Schema: bi
-- Cross-schema: treasury
-- Query. داشبورد خزانه (§63–§66): بانک/صندوق/دریافت/پرداخت/چک‌ها.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);

DECLARE @BankTotal DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0);
DECLARE @CashTotal DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);
DECLARE @InToday DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate = @Today AND Direction = N'In'), 0);
DECLARE @OutToday DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate = @Today AND Direction = N'Out'), 0);
DECLARE @InMonth DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate >= @MonthStart AND Direction = N'In'), 0);
DECLARE @OutMonth DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate >= @MonthStart AND Direction = N'Out'), 0);
DECLARE @InYesterday DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate = @Yesterday AND Direction = N'In'), 0);
DECLARE @OutYesterday DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[CashMovements] WHERE MovementDate = @Yesterday AND Direction = N'Out'), 0);

DECLARE @ChequeDueToday DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE DueDate = @Today AND Status = N'Pending'), 0);
DECLARE @ChequeDue7 DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE DueDate BETWEEN @Today AND DATEADD(DAY, 7, @Today) AND Status = N'Pending'), 0);
DECLARE @ChequeDue30 DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE DueDate BETWEEN @Today AND DATEADD(DAY, 30, @Today) AND Status = N'Pending'), 0);
DECLARE @ChequeBounced DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE Status = N'Bounced'), 0);
DECLARE @ChequeIn DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE Direction = N'In' AND Status = N'Pending'), 0);
DECLARE @ChequeOut DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM [treasury].[Cheques] WHERE Direction = N'Out' AND Status = N'Pending'), 0);

SELECT N'bank_total' AS KpiKey, N'موجودی کل بانک' AS Title, ISNULL(@BankTotal, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'IRR' AS Unit, N'/treasury' AS Link, N'جمع ماندهٔ حساب‌های بانکی' AS Formula, N'treasury' AS Source
UNION ALL SELECT N'cash_total', N'موجودی کل صندوق', ISNULL(@CashTotal, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'جمع ماندهٔ صندوق‌ها', N'treasury'
UNION ALL SELECT N'in_today', N'دریافت امروز', ISNULL(@InToday, 0), ISNULL(@InYesterday, 0), @InToday - ISNULL(@InYesterday, 0),
       CASE WHEN ISNULL(@InYesterday, 0) <> 0 THEN (@InToday - @InYesterday) * 100.0 / @InYesterday ELSE NULL END,
       N'IRR', N'/treasury', N'دریافت‌های نقدی امروز', N'treasury'
UNION ALL SELECT N'out_today', N'پرداخت امروز', ISNULL(@OutToday, 0), ISNULL(@OutYesterday, 0), @OutToday - ISNULL(@OutYesterday, 0),
       CASE WHEN ISNULL(@OutYesterday, 0) <> 0 THEN (@OutToday - @OutYesterday) * 100.0 / @OutYesterday ELSE NULL END,
       N'IRR', N'/treasury', N'پرداخت‌های نقدی امروز', N'treasury'
UNION ALL SELECT N'in_month', N'دریافت ماه', ISNULL(@InMonth, 0), NULL, NULL, NULL, N'IRR', N'/treasury/reports', N'دریافت‌های ماه جاری', N'treasury'
UNION ALL SELECT N'out_month', N'پرداخت ماه', ISNULL(@OutMonth, 0), NULL, NULL, NULL, N'IRR', N'/treasury/reports', N'پرداخت‌های ماه جاری', N'treasury'
UNION ALL SELECT N'cheque_in', N'چک‌های دریافتی (در راه)', ISNULL(@ChequeIn, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'چک‌های دریافتی Pending', N'treasury'
UNION ALL SELECT N'cheque_out', N'چک‌های پرداختی (در راه)', ISNULL(@ChequeOut, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'چک‌های پرداختی Pending', N'treasury'
UNION ALL SELECT N'cheque_due_today', N'چک سررسید امروز', ISNULL(@ChequeDueToday, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'چک‌های Pending با سررسید امروز', N'treasury'
UNION ALL SELECT N'cheque_due_7', N'چک ۷ روز آینده', ISNULL(@ChequeDue7, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=treasury', N'چک‌های Pending تا ۷ روز آینده', N'treasury'
UNION ALL SELECT N'cheque_due_30', N'چک ۳۰ روز آینده', ISNULL(@ChequeDue30, 0), NULL, NULL, NULL, N'IRR', N'/bi?tab=treasury', N'چک‌های Pending تا ۳۰ روز آینده', N'treasury'
UNION ALL SELECT N'cheque_bounced', N'چک‌های برگشتی', ISNULL(@ChequeBounced, 0), NULL, NULL, NULL, N'IRR', N'/treasury', N'چک‌های با وضعیت Bounced', N'treasury';
