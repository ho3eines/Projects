-- =============================================
-- Tarazin.Data/Scripts/bi/BiCashForecast.sql
-- Schema: bi
-- Cross-schema: treasury, payroll
-- Query. پیش‌بینی جریان نقدی ۳۰ روز آینده (§15):
--   ورود: چک‌های دریافتی (Pending) بر اساس سررسید
--   خروج: چک‌های پرداختی (Pending) بر اساس سررسید + آخرین حقوق پرداختی در ابتدای ماه بعد
-- خروجی: سری (Bucket=روز, Label, Value1=ماندهٔ پیش‌بینی‌شده)
-- =============================================
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Start DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM [treasury].[BankAccounts] WHERE IsDeleted = 0), 0)
    + ISNULL((SELECT SUM(Balance) FROM [treasury].[CashBoxes] WHERE IsDeleted = 0), 0);
DECLARE @LastPayroll DECIMAL(18,2) = ISNULL((SELECT TOP 1 NetTotal FROM [payroll].[PayrollRuns] ORDER BY CreatedAt DESC), 0);
DECLARE @NextMonthFirst DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today) + 1, 1);

WITH days AS (
    SELECT TOP (30) number + 1 AS D
    FROM master..spt_values
    WHERE type = N'P'
    ORDER BY number
)
SELECT DATEADD(DAY, D - 1, @Today) AS Bucket,
       FORMAT(DATEADD(DAY, D - 1, @Today), N'MM/dd') AS Label,
       @Start
       + ISNULL((SELECT SUM(c.Amount) FROM [treasury].[Cheques] c
                 WHERE c.Direction = N'In' AND c.Status = N'Pending'
                   AND c.DueDate BETWEEN @Today AND DATEADD(DAY, D - 1, @Today)), 0)
       - ISNULL((SELECT SUM(c.Amount) FROM [treasury].[Cheques] c
                 WHERE c.Direction = N'Out' AND c.Status = N'Pending'
                   AND c.DueDate BETWEEN @Today AND DATEADD(DAY, D - 1, @Today)), 0)
       - CASE WHEN DATEADD(DAY, D - 1, @Today) = @NextMonthFirst THEN @LastPayroll ELSE 0 END AS Value1,
       0 AS Value2, 0 AS Value3, 0 AS Value4
FROM days
ORDER BY D;
