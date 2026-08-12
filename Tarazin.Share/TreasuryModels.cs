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
}

public class TreasuryDashboardRow
{
    public decimal TodayNet { get; set; }
    public decimal BankBalance { get; set; }
    public decimal CashBalance { get; set; }
    public int PendingCheques { get; set; }
}

public class BankRow
{
    public int BankId { get; set; }
    public string BankCode { get; set; } = "";
    public string Title { get; set; } = "";
}

public class BankAccountRow
{
    public int AccountId { get; set; }
    public string AccountName { get; set; } = "";
    public string AccountNo { get; set; } = "";
    public string BankName { get; set; } = "";
    public decimal Balance { get; set; }
}

public class CashBoxRow
{
    public int CashBoxId { get; set; }
    public string CashBoxCode { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal Balance { get; set; }
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
}
