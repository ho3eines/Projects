-- =============================================
-- Tarazin.Data/Scripts/bi/BiPayrollKpis.sql
-- Schema: bi
-- Cross-schema: payroll
-- Query. داشبورد حقوق و دستمزد (§76–§77): هزینهٔ دوره/تعداد پرسنل/متوسط حقوق.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);

DECLARE @PeriodCost DECIMAL(18,2) = ISNULL((
    SELECT SUM(NetTotal) FROM [payroll].[PayrollRuns]
    WHERE Period = FORMAT(@MonthStart, 'yyyyMM')), 0);
DECLARE @PrevPeriodCost DECIMAL(18,2) = ISNULL((
    SELECT SUM(NetTotal) FROM [payroll].[PayrollRuns]
    WHERE Period = FORMAT(@PrevMonthStart, 'yyyyMM')), 0);
DECLARE @EmployeeCount INT = ISNULL((SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsActive = 1 AND IsDeleted = 0), 0);
DECLARE @AvgSalary DECIMAL(18,2) = CASE WHEN @EmployeeCount = 0 THEN 0 ELSE @PeriodCost / @EmployeeCount END;

SELECT N'payroll_month' AS KpiKey, N'هزینهٔ حقوق ماه جاری' AS Title, ISNULL(@PeriodCost, 0) AS Amount, ISNULL(@PrevPeriodCost, 0) AS PrevAmount,
       @PeriodCost - ISNULL(@PrevPeriodCost, 0) AS Change,
       CASE WHEN ISNULL(@PrevPeriodCost, 0) <> 0 THEN (@PeriodCost - @PrevPeriodCost) * 100.0 / @PrevPeriodCost ELSE NULL END AS ChangePercent,
       N'IRR' AS Unit, N'/payroll' AS Link, N'خالص پرداختی دورهٔ جاری (PayrollRuns)' AS Formula, N'payroll' AS Source
UNION ALL SELECT N'employees', N'تعداد کارکنان فعال', ISNULL(@EmployeeCount, 0), NULL, NULL, NULL, N'نفر', N'/payroll', N'کارمندان فعال', N'payroll'
UNION ALL SELECT N'avg_salary', N'متوسط حقوق', ISNULL(@AvgSalary, 0), NULL, NULL, NULL, N'IRR', N'/payroll/reports', N'هزینهٔ ماه ÷ تعداد پرسنل', N'payroll';
