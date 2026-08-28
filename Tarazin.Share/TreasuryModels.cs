namespace Tarazin.Models;

public class DailyCashMovementRow
{
    public int MovementId { get; set; }
    public string MovementNumber { get; set; } = "";
    public DateTime MovementDate { get; set; }
    public string Direction { get; set; } = "";
    public decimal Amount { get; set; }
    public string CurrencyCode { get; set; } = "IRR";
    public string AccountName { get; set; } = "";
    public string? Description { get; set; }
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class TreasuryDashboardRow
{
    public decimal TodayNet { get; set; }
    public decimal BankBalance { get; set; }
    public decimal CashBalance { get; set; }
    public int PendingCheques { get; set; }
    /// <summary>چک‌های باز (در انتظار/در جریان) که سررسیدشان گذشته است.</summary>
    public int OverdueCheques { get; set; }
}

public class BankRow
{
    public int BankId { get; set; }
    public string BankCode { get; set; } = "";
    public string Title { get; set; } = "";
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class BankAccountRow
{
    public int AccountId { get; set; }
    public string AccountName { get; set; } = "";
    public string AccountNo { get; set; } = "";
    public string BankName { get; set; } = "";
    public int? BankId { get; set; }
    public decimal Balance { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class CashBoxRow
{
    public int CashBoxId { get; set; }
    public string CashBoxCode { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal Balance { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class CashFlowRow
{
    public DateTime MovementDate { get; set; }
    public string MovementNumber { get; set; } = "";
    public string Direction { get; set; } = "";
    public decimal Amount { get; set; }
    public string CurrencyCode { get; set; } = "IRR";
    public string AccountName { get; set; } = "";
    public string? Description { get; set; }
    public string Status { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public class ChequeRow
{
    public int ChequeId { get; set; }
    public string ChequeNumber { get; set; } = "";
    public string BankName { get; set; } = "";
    public decimal Amount { get; set; }
    public DateTime? DueDate { get; set; }
    public string Direction { get; set; } = "";
    public string Status { get; set; } = "";
    public DateTime? CollectedAt { get; set; }
    public DateTime? ReturnedAt { get; set; }
    public string? ReturnReason { get; set; }
    public string? SourceReference { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>خلاصهٔ هشدار چک‌ها برای داشبورد اصلی (تعداد سررسیدشده و نزدیک).</summary>
public class ChequeAlertSummaryRow
{
    public int OverdueCount { get; set; }
    public int DueSoonCount { get; set; }
}

/// <summary>ردیف گزارش چک‌های در جریان و سررسیدشده با هشدار سررسید.</summary>
public class ChequeDueRow
{
    public int ChequeId { get; set; }
    public string ChequeNumber { get; set; } = "";
    public string BankName { get; set; } = "";
    public decimal Amount { get; set; }
    public DateTime? DueDate { get; set; }
    public string Direction { get; set; } = "";
    public string Status { get; set; } = "";
    public string? SourceReference { get; set; }
    /// <summary>روزهای مانده تا سررسید (منفی = سررسید گذشته).</summary>
    public int DaysToDue { get; set; }
    /// <summary>Overdue | DueSoon | OnTime</summary>
    public string AlertLevel { get; set; } = "OnTime";
}

/// <summary>تنظیمات اتصال خزانه به حسابداری (حساب صندوق/بانک + حساب مقابل + گروه‌های تفصیلی).</summary>
public class TreasurySettingsRow
{
    public int CompanyId { get; set; }
    public int? CashAccountId { get; set; }
    public string? CashAccountTitle { get; set; }
    public string? CashAccountCode { get; set; }
    public int? BankChartAccountId { get; set; }
    public string? BankChartAccountTitle { get; set; }
    public string? BankChartAccountCode { get; set; }
    public int? ReceiveContraAccountId { get; set; }
    public string? ReceiveContraAccountTitle { get; set; }
    public string? ReceiveContraAccountCode { get; set; }
    public int? PayContraAccountId { get; set; }
    public string? PayContraAccountTitle { get; set; }
    public string? PayContraAccountCode { get; set; }
    public int? CustomerAccountGroupId { get; set; }
    public string? CustomerAccountGroupTitle { get; set; }
    public int? SupplierAccountGroupId { get; set; }
    public string? SupplierAccountGroupTitle { get; set; }
    public int? DefaultCashBoxId { get; set; }
    public string? DefaultCashBoxTitle { get; set; }
    public int? DefaultBankAccountId { get; set; }
    public string? DefaultBankAccountTitle { get; set; }
    public bool IsEnabled { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>طرف حساب یکپارچه خزانه (مشتری/تأمین‌کننده) — همان central.Parties مشترک.</summary>
public class TreasuryPartyRow
{
    public int PartyId { get; set; }
    public string PartyCode { get; set; } = "";
    public string PartyType { get; set; } = "Customer";
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public bool IsActive { get; set; }
    public int? DetailLinkId { get; set; }
    public string? DetailAccountCode { get; set; }
}

public class TreasuryPartyEditModel
{
    public int PartyId { get; set; }
    public string PartyCode { get; set; } = "";
    public string PartyType { get; set; } = "Customer";
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public int? DetailLinkId { get; set; }
    public string? DetailAccountCode { get; set; }
    public bool IsActive { get; set; } = true;
}
