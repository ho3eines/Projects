namespace Tarazin.Models;

public class EmployeeRow
{
    public int EmployeeId { get; set; }
    public string EmployeeCode { get; set; } = "";
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }
    public string Department { get; set; } = "";
    public decimal BaseSalary { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class SalaryItemRow
{
    public int SalaryItemId { get; set; }
    public int EmployeeId { get; set; }
    public string Period { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal Amount { get; set; }
    public bool IsDeduction { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

public class PaySlipRow
{
    public int RunItemId { get; set; }
    public int EmployeeId { get; set; }
    public string EmployeeName { get; set; } = "";
    public decimal NetPay { get; set; }
    public string Period { get; set; } = "";
}

public class PayrollDashboardRow
{
    public int ActiveEmployees { get; set; }
    public int TotalRuns { get; set; }
    public decimal TotalPaid { get; set; }
    public string? LatestPeriod { get; set; }
}
