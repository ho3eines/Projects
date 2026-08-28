-- =============================================
-- Tarazin.Data/Scripts/payroll/MonthlyOpenSummary.sql
-- Schema: payroll
-- Query. خلاصه وضعیت ماه جاری
--
-- برگرداندن وضعیت دورهٔ جاری (Draft/Finalized/Closed) + آمار
-- اگر دوره‌ای باز نیست، Status = NULL برمی‌گرداند.
-- =============================================
SELECT
    r.RunId,
    r.Period,
    r.Status,
    r.EmployeeCount,
    r.NetTotal,
    r.CreatedAt,
    r.UpdatedAt,
    -- تعداد کارمندان فعال (بدون حکم)
    (SELECT COUNT(*) FROM [payroll].[Employees] e
     WHERE e.IsActive = 1 AND e.IsDeleted = 0 AND e.CompanyId = @CompanyId
       AND NOT EXISTS (SELECT 1 FROM [payroll].[EmploymentOrders] eo
                       WHERE eo.EmployeeId = e.EmployeeId AND eo.IsActive = 1)) AS EmployeesWithoutOrder,
    -- تعداد حکم‌های فعال
    (SELECT COUNT(*) FROM [payroll].[EmploymentOrders] eo
     WHERE eo.IsActive = 1 AND eo.CompanyId = @CompanyId) AS ActiveOrders,
    -- آیا اقلامی برای این دوره ثبت شده؟
    (SELECT COUNT(*) FROM [payroll].[SalaryItems] s WHERE s.Period = r.Period) AS SalaryItemCount
FROM [payroll].[PayrollRuns] r
WHERE r.Period = @Period
  AND r.CompanyId = @CompanyId;
