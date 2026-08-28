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
    public int? CompanyId { get; set; }
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
    public int? CompanyId { get; set; }
}

/// <summary>
/// Contrary: payroll.PaySlipDetail — فیش یک دوره با تجمیع اقلام (مزایا/کسورات)
/// و خالص ذخیره‌شده در دوره. مالیات با PayrollCalculationService در سمت C# محاسبه می‌شود.
/// </summary>
public class PaySlipDetailRow
{
    public int RunId { get; set; }
    public string Period { get; set; } = "";
    public int EmployeeCount { get; set; }
    public decimal NetTotal { get; set; }
    public int EmployeeId { get; set; }
    public string EmployeeName { get; set; } = "";
    public decimal StoredNet { get; set; }
    public decimal TotalEarnings { get; set; }
    public decimal TotalDeductions { get; set; }
}

public class PayrollDashboardRow
{
    public int ActiveEmployees { get; set; }
    public int TotalRuns { get; set; }
    public decimal TotalPaid { get; set; }
    public string? LatestPeriod { get; set; }
}

/// <summary>Contract: payroll.Outbox — ردیف رویداد برای دیسپچر پس‌زمینه.</summary>
public class PayrollOutboxRow
{
    public long OutboxId { get; set; }
    public string EventType { get; set; } = "";
    public string EventKey { get; set; } = "";
    public string Payload { get; set; } = "";
    public int PayloadVersion { get; set; } = 1;
    public DateTime CreatedAt { get; set; }
    public DateTime? ProcessedAt { get; set; }
    public int Attempts { get; set; }
    public string? LastError { get; set; }
    public DateTime? ClaimedAt { get; set; }
}

/// <summary>
/// Payload رویداد PayrollFinalized (که PayrollFinalize.sql با FOR JSON می‌سازد).
/// نگاشت با System.Text.Json انجام می‌شود؛ نام ویژگی‌ها باید با خروجی JSON یکی باشد.
/// </summary>
public sealed record PayrollFinalizedEvent(
    int RunId,
    string Period,
    int EmployeeCount,
    decimal NetTotal,
    int? CompanyId);
