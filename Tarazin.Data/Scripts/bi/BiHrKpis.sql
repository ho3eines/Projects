-- =============================================
-- Tarazin.Data/Scripts/bi/BiHrKpis.sql
-- Schema: bi
-- Cross-schema: payroll
-- Query. داشبورد منابع انسانی (§75/§78): پرسنل، استخدام جدید، دپارتمان‌ها.
-- خروجی: ردیف‌های KPI.
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
DECLARE @PrevMonthStart DATE = DATEADD(MONTH, -1, @MonthStart);
DECLARE @PrevMonthEnd DATE = DATEADD(DAY, -1, @MonthStart);

DECLARE @Total INT = ISNULL((SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsDeleted = 0), 0);
DECLARE @Active INT = ISNULL((SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsActive = 1 AND IsDeleted = 0), 0);
DECLARE @NewMonth INT = ISNULL((SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsDeleted = 0 AND CreatedAt >= @MonthStart), 0);
DECLARE @PrevNewMonth INT = ISNULL((SELECT COUNT(*) FROM [payroll].[Employees] WHERE IsDeleted = 0 AND CreatedAt BETWEEN @PrevMonthStart AND @PrevMonthEnd), 0);
DECLARE @Departments INT = ISNULL((SELECT COUNT(DISTINCT Department) FROM [payroll].[Employees] WHERE IsDeleted = 0 AND Department IS NOT NULL AND Department <> N''), 0);

SELECT N'hr_total' AS KpiKey, N'کل کارکنان' AS Title, ISNULL(@Total, 0) AS Amount, NULL AS PrevAmount, NULL AS Change, NULL AS ChangePercent,
       N'نفر' AS Unit, N'/payroll' AS Link, N'تعداد کارمندان (غیرحذف)' AS Formula, N'payroll' AS Source, N'Neutral' AS Status
UNION ALL SELECT N'hr_active', N'کارکنان فعال', ISNULL(@Active, 0), NULL, NULL, NULL, N'نفر', N'/payroll', N'کارمندان IsActive=1', N'payroll', N'Neutral'
UNION ALL SELECT N'hr_new_month', N'استخدام جدید ماه', ISNULL(@NewMonth, 0), ISNULL(@PrevNewMonth, 0),
       @NewMonth - ISNULL(@PrevNewMonth, 0),
       CASE WHEN ISNULL(@PrevNewMonth, 0) <> 0 THEN (@NewMonth - @PrevNewMonth) * 100.0 / @PrevNewMonth ELSE NULL END,
       N'نفر', N'/payroll', N'کارمندان ساخته‌شده در ماه جاری', N'payroll', N'Neutral'
UNION ALL SELECT N'hr_departments', N'تعداد دپارتمان‌ها', ISNULL(@Departments, 0), NULL, NULL, NULL, N'دپارتمان', N'/payroll', N'دپارتمان‌های متمایز', N'payroll', N'Neutral';
