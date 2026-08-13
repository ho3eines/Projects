-- =============================================
-- Tarazin.Data/Scripts/bi/BiExpenseKpis.sql
-- Schema: bi
-- Cross-schema: accounting
-- Query. تحلیل هزینه (§68): هزینه امروز/ماه/سال از دفتر کل + مقایسه ماه قبل.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Yesterday DATE = DATEADD(DAY, -1, @Today);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);
DECLARE @YearStart DATE = DATEFROMPARTS(YEAR(@Today), 1, 1);

DECLARE @ExpenseToday DECIMAL(18,2) = ISNULL((
    SELECT SUM(l.Debit) FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate = @Today AND a.AccountType = N'Expense'), 0);
DECLARE @ExpenseYesterday DECIMAL(18,2) = ISNULL((
    SELECT SUM(l.Debit) FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate = @Yesterday AND a.AccountType = N'Expense'), 0);
DECLARE @ExpenseMonth DECIMAL(18,2) = ISNULL((
    SELECT SUM(l.Debit) FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate >= @MonthStart AND a.AccountType = N'Expense'), 0);
DECLARE @ExpensePrevMonth DECIMAL(18,2) = ISNULL((
    SELECT SUM(l.Debit) FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate BETWEEN @PrevMonthStart AND @PrevMonthEnd AND a.AccountType = N'Expense'), 0);
DECLARE @ExpenseYear DECIMAL(18,2) = ISNULL((
    SELECT SUM(l.Debit) FROM [accounting].[DocumentLines] l
    JOIN [accounting].[Documents] d ON d.DocumentId = l.DocumentId
    JOIN [accounting].[ChartOfAccounts] a ON a.AccountId = l.AccountId
    WHERE d.Status = N'Posted' AND d.IsDeleted = 0 AND d.DocumentDate >= @YearStart AND a.AccountType = N'Expense'), 0);

SELECT N'expense_today' AS KpiKey, N'هزینه امروز' AS Title, ISNULL(@ExpenseToday, 0) AS Amount, ISNULL(@ExpenseYesterday, 0) AS PrevAmount,
       @ExpenseToday - ISNULL(@ExpenseYesterday, 0) AS Change,
       CASE WHEN ISNULL(@ExpenseYesterday, 0) <> 0 THEN (@ExpenseToday - @ExpenseYesterday) * 100.0 / @ExpenseYesterday ELSE NULL END AS ChangePercent,
       N'IRR' AS Unit, N'/accounting' AS Link, N'بدهکار حساب‌های Expense (دفتر کل)' AS Formula, N'accounting' AS Source,
       CASE WHEN @ExpenseToday > ISNULL(@ExpenseYesterday, 0) * 1.3 THEN N'Bad' ELSE N'Neutral' END AS Status
UNION ALL SELECT N'expense_month', N'هزینه ماه', ISNULL(@ExpenseMonth, 0), ISNULL(@ExpensePrevMonth, 0),
       @ExpenseMonth - ISNULL(@ExpensePrevMonth, 0),
       CASE WHEN ISNULL(@ExpensePrevMonth, 0) <> 0 THEN (@ExpenseMonth - @ExpensePrevMonth) * 100.0 / @ExpensePrevMonth ELSE NULL END,
       N'IRR', N'/accounting/reports', N'هزینه از ابتدای ماه جاری', N'accounting',
       CASE WHEN @ExpenseMonth > ISNULL(@ExpensePrevMonth, 0) * 1.2 THEN N'Bad' ELSE N'Neutral' END
UNION ALL SELECT N'expense_year', N'هزینه سال', ISNULL(@ExpenseYear, 0), NULL, NULL, NULL, N'IRR', N'/accounting/reports', N'هزینه از ابتدای سال', N'accounting', N'Neutral';
