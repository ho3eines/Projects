namespace Tarazin.Models;

/// <summary>حکم اداری — قرارداد کارمند با جزئیات مزایا و نرخ بیمه.</summary>
public class EmploymentOrderRow
{
    public int OrderId { get; set; }
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = "";
    public string EmployeeName { get; set; } = "";
    public string Department { get; set; } = "";
    public string ContractType { get; set; } = "Permanent";
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public decimal BaseSalary { get; set; }
    public decimal HousingAllowance { get; set; }
    public decimal FoodAllowance { get; set; }
    public decimal TransportAllowance { get; set; }
    public decimal InsurancePct { get; set; } = 7.0m;
    public int TaxExemptCount { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Notes { get; set; }
    public int? CompanyId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>الگوی قلم حقوق (اضافات یا کسورات از پیش تعریف‌شده).</summary>
public class SalaryTemplateRow
{
    public int TemplateId { get; set; }
    public string Title { get; set; } = "";
    public string Category { get; set; } = "Earning"; // Earning | Deduction
    public bool IsPercent { get; set; }
    public decimal? Percentage { get; set; }
    public decimal? FixedAmount { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public int? CompanyId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>خلاصه وضعیت ماه جاری.</summary>
public class MonthlyOpenSummaryRow
{
    public int RunId { get; set; }
    public string Period { get; set; } = "";
    public string? Status { get; set; }
    public int EmployeeCount { get; set; }
    public decimal NetTotal { get; set; }
    public int EmployeesWithoutOrder { get; set; }
    public int ActiveOrders { get; set; }
    public int SalaryItemCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>ردیف حضورغیاب روزانه (ورود/خروج + کارکرد محاسبه‌شده).</summary>
public class AttendanceLogRow
{
    public int AttendanceId { get; set; }
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = "";
    public string EmployeeName { get; set; } = "";
    public int CompanyId { get; set; }
    public DateTime AttendanceDate { get; set; }
    public TimeSpan? CheckIn { get; set; }
    public TimeSpan? CheckOut { get; set; }
    public int WorkMinutes { get; set; }
    public int OvertimeMinutes { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>ردیف مرخصی کارمند (استحقاقی یا بدون حقوق).</summary>
public class LeaveRecordRow
{
    public int LeaveId { get; set; }
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = "";
    public string EmployeeName { get; set; } = "";
    public int CompanyId { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public decimal Days { get; set; } = 1;
    public string LeaveType { get; set; } = "Annual";
    public bool IsPaid { get; set; } = true;
    public string? Description { get; set; }
    public string? ApprovedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

/// <summary>خلاصه حضورغیاب ماهانه هر کارمند (برای فیش و گزارش).</summary>
public class AttendanceSummaryRow
{
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = "";
    public string EmployeeName { get; set; } = "";
    public int CompanyId { get; set; }
    public int WorkDays { get; set; }
    public int OvertimeMinutes { get; set; }
    public decimal PaidLeaveDays { get; set; }
    public decimal UnpaidLeaveDays { get; set; }
    public int AvgCheckInMinute { get; set; }
}

/// <summary>تنظیمات اتصال حقوق و دستمزد به حسابداری/خزانه.</summary>
public class PayrollSettingsRow
{
    public int SettingId { get; set; }
    public string? PayableAccountCode { get; set; }
    public string? InsuranceAccountCode { get; set; }
    public string? TaxAccountCode { get; set; }
    public string? BankAccountCode { get; set; }
    public string? DocumentPrefix { get; set; }
    public int? CompanyId { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
