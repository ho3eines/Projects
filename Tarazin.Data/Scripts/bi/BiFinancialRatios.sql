-- =============================================
-- Tarazin.Data/Scripts/bi/BiFinancialRatios.sql
-- Schema: bi
-- Cross-schema: accounting, treasury, currency, goldshop, store, inventory
-- Query. نسبت‌های مالی (§7/§20/§24/§94): حاشیه سود، DSO، نسبت‌های نقدینگی/بدهی.
-- وضعیت (Status) با «زمینهٔ کسب‌وکار» تعیین می‌شود (§116): مثلاً افزایش بدهی = بد.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);

-- فروش ماه (طلا + فروشگاه + ارز)
DECLARE @SalesMonth DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate >= @MonthStart AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate >= @MonthStart AND TransactionType = N'Sell'), 0);
DECLARE @SalesPrev DECIMAL(18,2) = ISNULL((SELECT SUM(TotalAmount) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0)
    + ISNULL((SELECT SUM(TotalAmount) FROM [store].[Orders] WHERE OrderDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND Status = N'Invoiced'), 0)
    + ISNULL((SELECT SUM(TotalRial) FROM [currency].[FxTransactions] WHERE TransactionDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND TransactionType = N'Sell'), 0);

-- سود ناخالص ماه (اجرت+سود طلا + سود محقق‌شدهٔ ارز)
DECLARE @ProfitMonth DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(Workmanship,0)+ISNULL(Profit,0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate >= @MonthStart), 0)
    + ISNULL((SELECT SUM(ISNULL(l.RealizedPnl,0)) FROM [currency].[FxTransactionLegs] l JOIN [currency].[FxTransactions] t ON t.FxTransactionId=l.FxTransactionId WHERE t.TransactionDate >= @MonthStart), 0);

-- سود خالص (دفتر کل: درآمد − هزینه در ماه)
DECLARE @NetMonth DECIMAL(18,2) = ISNULL((
    SELECT SUM(CASE WHEN a.AccountType = N'Income' THEN l.Credit ELSE -l.Debit END)
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate >= @MonthStart
      AND a.AccountType IN (N'Income', N'Expense')), 0);

-- نقدینگی / مطالبات / بدهی / موجودی
DECLARE @Cash DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0)
    + ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0);
DECLARE @Receivable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Debit,0)-ISNULL(l.Credit,0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Asset' AND a.IsDeleted = 0 AND a.AccountCode NOT IN (N'1000',N'1010',N'1020',N'1030',N'1040')), 0);
DECLARE @Payable DECIMAL(18,2) = ISNULL((
    SELECT SUM(ISNULL(l.Credit,0)-ISNULL(l.Debit,0))
    FROM [accounting].[DocumentLines] l
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE a.AccountType = N'Liability' AND a.IsDeleted = 0), 0);
DECLARE @Inventory DECIMAL(18,2) = ISNULL((SELECT SUM(ISNULL(StockQty,0)*ISNULL(UnitPrice,0)) FROM [inventory].[Items] WHERE IsDeleted = 0), 0);

-- محاسبهٔ نسبت‌ها (با محافظت از تقسیم بر صفر)
DECLARE @GrossMargin DECIMAL(12,2) = CASE WHEN @SalesMonth = 0 THEN NULL ELSE ROUND(@ProfitMonth * 100.0 / @SalesMonth, 2) END;
DECLARE @NetMargin DECIMAL(12,2) = CASE WHEN @SalesMonth = 0 THEN NULL ELSE ROUND(@NetMonth * 100.0 / @SalesMonth, 2) END;
DECLARE @DaysInMonth INT = DAY(EOMONTH(@Today));
DECLARE @Dso DECIMAL(12,2) = CASE WHEN @SalesMonth = 0 THEN NULL ELSE ROUND(@Receivable / (@SalesMonth / @DaysInMonth), 1) END;
DECLARE @CurrentRatio DECIMAL(12,2) = CASE WHEN @Payable = 0 THEN NULL ELSE ROUND((@Cash + @Receivable + @Inventory) / @Payable, 2) END;
DECLARE @QuickRatio DECIMAL(12,2) = CASE WHEN @Payable = 0 THEN NULL ELSE ROUND((@Cash + @Receivable) / @Payable, 2) END;
DECLARE @CashRatio DECIMAL(12,2) = CASE WHEN @Payable = 0 THEN NULL ELSE ROUND(@Cash / @Payable, 2) END;
DECLARE @Assets DECIMAL(18,2) = @Cash + @Receivable + @Inventory;
DECLARE @DebtRatio DECIMAL(12,2) = CASE WHEN @Assets = 0 THEN NULL ELSE ROUND(@Payable * 100.0 / @Assets, 2) END;

SELECT N'gross_margin' AS KpiKey, N'حاشیه سود ناخالص' AS Title, ISNULL(@GrossMargin, 0) AS Amount,
       CASE WHEN @SalesPrev = 0 THEN NULL ELSE ROUND(
           (ISNULL((SELECT SUM(ISNULL(Workmanship,0)+ISNULL(Profit,0)) FROM [goldshop].[SaleInvoices] WHERE InvoiceDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0)
          + ISNULL((SELECT SUM(ISNULL(l.RealizedPnl,0)) FROM [currency].[FxTransactionLegs] l JOIN [currency].[FxTransactions] t ON t.FxTransactionId=l.FxTransactionId WHERE t.TransactionDate BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0)) * 100.0 / @SalesPrev, 2) END AS PrevAmount,
       NULL AS Change, NULL AS ChangePercent,
       N'٪' AS Unit, N'/currency/dashboard' AS Link,
       N'سود ناخالص ماه ÷ فروش ماه × ۱۰۰ (اجرت+سود طلا + سود ارز)' AS Formula, N'goldshop/currency' AS Source,
       CASE WHEN ISNULL(@GrossMargin, 0) >= 5 THEN N'Good' ELSE N'Bad' END AS Status
UNION ALL SELECT N'net_margin', N'حاشیه سود خالص', ISNULL(@NetMargin, 0), NULL, NULL, NULL, N'٪', N'/accounting/reports',
       N'(درآمد − هزینه) دفتر کل ÷ فروش ماه × ۱۰۰', N'accounting', CASE WHEN ISNULL(@NetMargin, 0) >= 0 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'dso', N'DSO — روز وصول مطالبات', ISNULL(@Dso, 0), NULL, NULL, NULL, N'روز', N'/bi?tab=customers',
       N'مطالبات ÷ (فروش ماه ÷ روزهای ماه)', N'accounting', CASE WHEN ISNULL(@Dso, 0) <= 45 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'current_ratio', N'Current Ratio', ISNULL(@CurrentRatio, 0), NULL, NULL, NULL, N'نسبت', N'/bi?tab=payables',
       N'(نقد + مطالبات + موجودی) ÷ بدهی‌ها', N'multi', CASE WHEN ISNULL(@CurrentRatio, 0) >= 1 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'quick_ratio', N'Quick Ratio', ISNULL(@QuickRatio, 0), NULL, NULL, NULL, N'نسبت', N'/bi?tab=payables',
       N'(نقد + مطالبات) ÷ بدهی‌ها', N'multi', CASE WHEN ISNULL(@QuickRatio, 0) >= 1 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'cash_ratio', N'Cash Ratio', ISNULL(@CashRatio, 0), NULL, NULL, NULL, N'نسبت', N'/treasury',
       N'نقد (بانک+صندوق) ÷ بدهی‌ها', N'treasury', CASE WHEN ISNULL(@CashRatio, 0) >= 0.5 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'debt_ratio', N'نسبت بدهی (Debt Ratio)', ISNULL(@DebtRatio, 0), NULL, NULL, NULL, N'٪', N'/bi?tab=payables',
       N'بدهی‌ها ÷ کل دارایی‌ها × ۱۰۰ — افزایش بدهی الزاماً خوب نیست (§116)', N'accounting', CASE WHEN ISNULL(@DebtRatio, 0) <= 50 THEN N'Good' ELSE N'Bad' END
UNION ALL SELECT N'inv_turnover', N'گردش موجودی (پروکسی)', CASE WHEN @Inventory = 0 THEN 0 ELSE ROUND(@SalesMonth / @Inventory, 2) END, NULL, NULL, NULL,
       N'نسبت', N'/inventory/reports', N'فروش ماه ÷ ارزش موجودی (نسبت پوشش دارایی)', N'inventory', N'Neutral';
