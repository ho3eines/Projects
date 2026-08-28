-- =============================================
-- Tarazin.Data/Scripts/payroll/AttendanceSummary.sql
-- Schema: payroll
-- Query. خلاصه حضورغیاب هر کارمند برای یک بازهٔ تاریخ (میلادی).
-- بازه را C# از روی دورهٔ شمسی با PersianCalendar دقیق محاسبه می‌کند.
-- پارامترها: @CompanyId, @FromDate, @ToDate, @EmployeeId (اختیاری)
-- =============================================
SELECT
    e.EmployeeId,
    e.EmployeeCode,
    e.FullName AS EmployeeName,
    e.CompanyId,
    COUNT(a.AttendanceId) AS WorkDays,
    ISNULL(SUM(a.OvertimeMinutes), 0) AS OvertimeMinutes,
    ISNULL((SELECT SUM(l.Days) FROM [payroll].[LeaveRecords] l
            WHERE l.EmployeeId = e.EmployeeId AND l.IsPaid = 1
              AND l.StartDate BETWEEN @FromDate AND @ToDate), 0) AS PaidLeaveDays,
    ISNULL((SELECT SUM(l.Days) FROM [payroll].[LeaveRecords] l
            WHERE l.EmployeeId = e.EmployeeId AND l.IsPaid = 0
              AND l.StartDate BETWEEN @FromDate AND @ToDate), 0) AS UnpaidLeaveDays,
    -- میانگین ساعت ورود روزهای ثبت‌شده (دقیقه از نیمه‌شب)
    ISNULL((SELECT AVG(DATEDIFF(MINUTE, '00:00', CAST(a2.CheckIn AS TIME)))
            FROM [payroll].[AttendanceLogs] a2
            WHERE a2.EmployeeId = e.EmployeeId AND a2.CheckIn IS NOT NULL
              AND a2.AttendanceDate BETWEEN @FromDate AND @ToDate), 0) AS AvgCheckInMinute
FROM [payroll].[Employees] e
LEFT JOIN [payroll].[AttendanceLogs] a
       ON a.EmployeeId = e.EmployeeId
      AND a.AttendanceDate BETWEEN @FromDate AND @ToDate
WHERE e.IsDeleted = 0
  AND e.CompanyId = @CompanyId
  AND (@EmployeeId IS NULL OR @EmployeeId = 0 OR e.EmployeeId = @EmployeeId)
GROUP BY e.EmployeeId, e.EmployeeCode, e.FullName, e.CompanyId
ORDER BY e.FullName ASC;
