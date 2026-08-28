-- =============================================
-- Tarazin.Data/Scripts/payroll/LeaveList.sql
-- Schema: payroll
-- Query. فهرست مرخصی‌ها (فیلتر: شرکت + بازه + اختیاری کارمند)
-- =============================================
SELECT
    l.LeaveId,
    l.EmployeeId,
    e.EmployeeCode,
    e.FullName AS EmployeeName,
    l.CompanyId,
    l.StartDate,
    l.EndDate,
    l.Days,
    l.LeaveType,
    l.IsPaid,
    l.Description,
    l.ApprovedBy,
    l.CreatedAt,
    l.UpdatedAt,
    l.CreatedBy
FROM [payroll].[LeaveRecords] l
INNER JOIN [payroll].[Employees] e ON e.EmployeeId = l.EmployeeId AND e.IsDeleted = 0
WHERE l.CompanyId = @CompanyId
  AND l.StartDate BETWEEN @FromDate AND @ToDate
  AND (@EmployeeId IS NULL OR @EmployeeId = 0 OR l.EmployeeId = @EmployeeId)
ORDER BY l.StartDate DESC, e.FullName ASC;
