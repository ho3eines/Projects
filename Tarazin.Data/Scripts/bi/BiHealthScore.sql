-- =============================================
-- Tarazin.Data/Scripts/bi/BiHealthScore.sql
-- Schema: bi
-- Cross-schema: goldshop, store, currency, treasury, accounting
-- Query. امتیاز سلامت کسب‌وکار (§119) — Business Health Score 0..100
-- از دادهٔ واقعی: رشد فروش، سودآوری، نقدینگی، مطالبات، بدهی.
-- خروجی: (Score, Grade, Summary)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);

DECLARE @SalesMonth DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate >= @MonthStart AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell'), 0);
DECLARE @SalesPrev DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND TransactionType = N'Sell'), 0);
DECLARE @ProfitMonth DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(Workmanship, 0) + ISNULL(Profit, 0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0)
    + ISNULL((SELECT SUM(ISNULL(l.RealizedPnl, 0)) FROM [currency].[FxTransactionLegs] l JOIN [currency].[FxTransactions] t ON t.FxTransactionId = l.FxTransactionId WHERE t.TransactionDate >= @MonthStart), 0);
DECLARE @Liquidity DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0)
    + ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);
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

-- امتیاز: هر بخش ۰..۲۵
DECLARE @GrowthScore DECIMAL(9,2) = CASE WHEN ISNULL(@SalesPrev, 0) = 0 THEN 15
    ELSE 25 * (0.5 + 0.5 * CASE WHEN @SalesMonth >= @SalesPrev THEN 1 ELSE @SalesMonth / NULLIF(@SalesPrev, 0) END) END;
DECLARE @ProfitScore DECIMAL(9,2) = CASE WHEN ISNULL(@SalesMonth, 0) = 0 THEN 0
    ELSE 25 * (1 - CASE WHEN @ProfitMonth < 0 THEN 0.5 ELSE 0 END) * CASE WHEN @SalesMonth > 0 THEN 1 ELSE 0 END
         * (0.5 + 0.5 * CASE WHEN @SalesMonth > 0 THEN @ProfitMonth / @SalesMonth ELSE 0 END) END;
DECLARE @LiquidityScore DECIMAL(9,2) = CASE WHEN ISNULL(@Payable, 0) = 0 THEN 20
    ELSE 25 * CASE WHEN @Liquidity >= @Payable THEN 1 ELSE @Liquidity / NULLIF(@Payable, 0) END END;
DECLARE @ReceivableScore DECIMAL(9,2) = CASE WHEN ISNULL(@SalesMonth, 0) = 0 THEN 15
    ELSE 25 * (1 - CASE WHEN @Receivable > @SalesMonth * 2 THEN 0.6 ELSE @Receivable / NULLIF(@SalesMonth * 2, 0) END) END;

DECLARE @Score INT = CAST(ROUND(@GrowthScore + @ProfitScore + @LiquidityScore + @ReceivableScore, 0) AS INT);
IF @Score > 100 SET @Score = 100;
IF @Score < 0 SET @Score = 0;

SELECT @Score AS Score,
       CASE WHEN @Score >= 80 THEN N'عالی' WHEN @Score >= 60 THEN N'خوب'
            WHEN @Score >= 40 THEN N'متوسط' ELSE N'ضعیف' END AS Grade,
       N'رشد فروش ماه: ' + FORMAT(ISNULL(@SalesMonth, 0), 'N0') + N' (ماه قبل: ' + FORMAT(ISNULL(@SalesPrev, 0), 'N0') + N') — سود ماه: '
       + FORMAT(ISNULL(@ProfitMonth, 0), 'N0') + N' — نقدینگی: ' + FORMAT(ISNULL(@Liquidity, 0), 'N0')
       + N' — مطالبات: ' + FORMAT(ISNULL(@Receivable, 0), 'N0') + N' — بدهی‌ها: ' + FORMAT(ISNULL(@Payable, 0), 'N0') AS Summary;
