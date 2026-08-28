-- =============================================
-- Tarazin.Data/Scripts/payroll/AttendanceList.sql
-- Schema: payroll
-- Query. فهرست حضورغیاب (فیلتر: شرکت + بازه تاریخ + اختیاری کارمند)
-- =============================================
SELECT
    a.AttendanceId,
    a.EmployeeId,
    e.EmployeeCode,
    e.FullName AS EmployeeName,
    a.CompanyId,
    a.AttendanceDate,
    a.CheckIn,
    a.CheckOut,
    a.WorkMinutes,
    a.OvertimeMinutes,
    a.Notes,
    a.CreatedAt,
    a.UpdatedAt,
    a.CreatedBy
FROM [payroll].[AttendanceLogs] a
INNER JOIN [payroll].[Employees] e ON e.EmployeeId = a.EmployeeId AND e.IsDeleted = 0
WHERE a.CompanyId = @CompanyId
  AND a.AttendanceDate BETWEEN @FromDate AND @ToDate
  AND (@EmployeeId IS NULL OR @EmployeeId = 0 OR a.EmployeeId = @EmployeeId)
ORDER BY a.AttendanceDate DESC, e.FullName ASC;
