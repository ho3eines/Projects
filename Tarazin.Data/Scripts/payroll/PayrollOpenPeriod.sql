-- =============================================
-- Tarazin.Data/Scripts/payroll/PayrollOpenPeriod.sql
-- Schema: payroll
-- Execute. باز کردن دوره جدید حقوق از روی حکم‌ها
--
-- این اسکریپت:
--   ۱) یک PayrollRun با وضعیت Draft ایجاد می‌کند (اگر وجود نداشته باشد)
--   ۲) برای هر کارمند فعالی که حکم فعال دارد، اقلام حقوق را خودکار پر می‌کند:
--      - حقوق پایه (از حکم)
--      - حق مسکن (از حکم)
--      - حق خوراک (از حکم)
--      - حق حمل (از حکم)
--      - بیمه سهم کارمند (از درصد حکم)
-- =============================================
IF EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE Period = @Period AND Status IN (N'Finalized', N'Closed'))
    THROW 51021, N'این دوره قبلاً نهایی یا بسته شده است', 1;

-- ایجاد ردیف دوره (اگر وجود نداشته باشد)
IF NOT EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE Period = @Period)
BEGIN
    INSERT INTO [payroll].[PayrollRuns] (Period, EmployeeCount, NetTotal, Status, CreatedAt, CreatedBy, CompanyId)
    VALUES (@Period, 0, 0, N'Draft', SYSUTCDATETIME(), @CreatedBy, @CompanyId);
END

DECLARE @RunId INT = (SELECT RunId FROM [payroll].[PayrollRuns] WHERE Period = @Period);

-- حذف اقلام قبلی این دوره (اگر Draft باشد — اجازه بازنویسی)
IF EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE RunId = @RunId AND Status = N'Draft')
BEGIN
    DELETE FROM [payroll].[SalaryItems] WHERE Period = @Period;
END

-- پر کردن خودکار اقلام از روی حکم‌های فعال
INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId,
    @Period,
    N'حقوق پایه',
    eo.BaseSalary,
    0,
    SYSUTCDATETIME(),
    @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'حقوق پایه')
  AND eo.BaseSalary > 0;

INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId, @Period, N'حق مسکن', eo.HousingAllowance, 0, SYSUTCDATETIME(), @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'حق مسکن')
  AND eo.HousingAllowance > 0;

INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId, @Period, N'حق خوراک', eo.FoodAllowance, 0, SYSUTCDATETIME(), @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'حق خوراک')
  AND eo.FoodAllowance > 0;

INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId, @Period, N'حق حمل', eo.TransportAllowance, 0, SYSUTCDATETIME(), @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'حق حمل')
  AND eo.TransportAllowance > 0;

INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId, @Period, N'بیمه سهم کارمند', ROUND(eo.BaseSalary * eo.InsurancePct / 100, 0), 1, SYSUTCDATETIME(), @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'بیمه سهم کارمند')
  AND eo.InsurancePct > 0;

-- ════════════════════════════════════════════════════════════════
-- حضورغیاب: محاسبهٔ خودکار اقلام از روی AttendanceLogs و LeaveRecords
-- ════════════════════════════════════════════════════════════════
-- بازهٔ میلادی (@FromDate/@ToDate) را C# از روی دورهٔ شمسی با
-- PersianCalendar دقیق محاسبه می‌کند (نه تقریب 621+).
-- Fallback: اگر پاس نشد، دوره به فرمت N'1405-05' → بازهٔ تقریبی.
DECLARE @PY INT = TRY_CONVERT(INT, LEFT(@Period, 4));
DECLARE @PM INT = TRY_CONVERT(INT, RIGHT(@Period, 2));
IF @FromDate IS NULL
BEGIN
    SET @FromDate = DATEFROMPARTS(@PY + 621, @PM, 1);
    SET @ToDate = DATEADD(DAY, -1, DATEADD(MONTH, 1, @FromDate));
END

-- ۱) اضافه‌کار: نرخ ساعتی = پایه / 30 / 8 ، ضریب ۱٫۴
--     مبلغ = دقیقه اضافه‌کار / 60 × نرخ ساعتی × ۱٫۴
INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId, @Period, N'اضافه‌کار',
    ROUND(ISNULL((SELECT SUM(a.OvertimeMinutes) FROM [payroll].[AttendanceLogs] a
                  WHERE a.EmployeeId = e.EmployeeId
                    AND a.AttendanceDate BETWEEN @FromDate AND @ToDate), 0)
          / 60.0 * (eo.BaseSalary / 30 / 8) * 1.4, 0),
    0, SYSUTCDATETIME(), @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'اضافه‌کار')
  AND eo.BaseSalary > 0
  AND EXISTS (SELECT 1 FROM [payroll].[AttendanceLogs] a
             WHERE a.EmployeeId = e.EmployeeId AND a.OvertimeMinutes > 0
               AND a.AttendanceDate BETWEEN @FromDate AND @ToDate);

-- ۲) کسر مرخصی بدون حقوق: روز × (پایه / 30)
INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt, CompanyId)
SELECT
    e.EmployeeId, @Period, N'کسر مرخصی بدون حقوق',
    ROUND(ISNULL((SELECT SUM(l.Days) FROM [payroll].[LeaveRecords] l
                  WHERE l.EmployeeId = e.EmployeeId AND l.IsPaid = 0
                    AND l.StartDate BETWEEN @FromDate AND @ToDate), 0)
          * (eo.BaseSalary / 30), 0),
    1, SYSUTCDATETIME(), @CompanyId
FROM [payroll].[Employees] e
JOIN [payroll].[EmploymentOrders] eo ON eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1
WHERE e.IsActive = 1 AND e.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] s WHERE s.EmployeeId = e.EmployeeId AND s.Period = @Period AND s.Title = N'کسر مرخصی بدون حقوق')
  AND eo.BaseSalary > 0
  AND EXISTS (SELECT 1 FROM [payroll].[LeaveRecords] l
             WHERE l.EmployeeId = e.EmployeeId AND l.IsPaid = 0
               AND l.StartDate BETWEEN @FromDate AND @ToDate);

-- بروزرسانی تعداد کارمندان در ردیف دوره
UPDATE [payroll].[PayrollRuns]
SET EmployeeCount = (SELECT COUNT(DISTINCT EmployeeId) FROM [payroll].[SalaryItems] WHERE Period = @Period),
    NetTotal = (SELECT ISNULL(SUM(CASE WHEN IsDeduction = 1 THEN -Amount ELSE Amount END), 0) FROM [payroll].[SalaryItems] WHERE Period = @Period)
WHERE RunId = @RunId;
