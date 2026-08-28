namespace Tarazin.Models;

// ============================================================
// Shared models — used by more than one module.
// Column aliases in the named TSQL scripts MUST match these names.
// ============================================================

/// <summary>Base entity with common audit fields.</summary>
public abstract class BaseEntity
{
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public bool IsDeleted { get; set; }
}

/// <summary>Contract: Party (Core).</summary>
public class PartyRow
{
    public int PartyId { get; set; }
    public string PartyCode { get; set; } = "";
    public string PartyType { get; set; } = "";          // Customer | Vendor | Employee
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: ChartOfAccount (Accounting).</summary>
public class ChartOfAccountRow
{
    public int AccountId { get; set; }
    public string AccountCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? AccountType { get; set; }              // Asset | Liability | Equity | Income | Expense
    public int? ParentAccountId { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: CurrencyRate (Treasury).</summary>
public class CurrencyRateRow
{
    public int RateId { get; set; }
    public string CurrencyCode { get; set; } = "";
    public string CurrencyName { get; set; } = "";
    public decimal RateToIRR { get; set; }
    public DateTime RateDate { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

/// <summary>Contract: TaxRule (Accounting).</summary>
public class TaxRuleRow
{
    public int TaxRuleId { get; set; }
    public string RuleCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Category { get; set; }                 // Vat | Payroll | Gold | Commerce
    public decimal RatePercent { get; set; }
    public DateTime EffectiveFrom { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>Contract: InventoryMovement (Warehouse).</summary>
public class InventoryMovementRow
{
    public int MovementId { get; set; }
    public string MovementNumber { get; set; } = "";
    public string MovementType { get; set; } = "";        // Receipt | Issue | Adjustment
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public DateTime MovementDate { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: PayrollRun (Payroll).</summary>
public class PayrollRunRow
{
    public int RunId { get; set; }
    public string Period { get; set; } = "";
    public int EmployeeCount { get; set; }
    public decimal NetTotal { get; set; }
    public string Status { get; set; } = "";
    public int? CompanyId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Contract: GoldPrice (GoldShop).</summary>
public class GoldPriceRow
{
    public int PriceId { get; set; }
    public string ItemCode { get; set; } = "";
    public string Title { get; set; } = "";
    public decimal PricePerGram { get; set; }
    public decimal? RateToIRR { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

/// <summary>Contract: Order / Cart (E-Com).</summary>
public class OrderRow
{
    public int OrderId { get; set; }
    public string OrderNumber { get; set; } = "";
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = "";
    public int ItemCount { get; set; }
    public decimal TotalAmount { get; set; }
    public string CurrencyCode { get; set; } = "IRR";
    public string Status { get; set; } = "";
    public string PaymentStatus { get; set; } = "Unpaid";
    public decimal BalanceRial { get; set; }
    public decimal PayCash { get; set; }
    public decimal PayBank { get; set; }
    public string? ChequeNumber { get; set; }
    public int? ChequeBankId { get; set; }
    public decimal ChequeAmount { get; set; }
    public DateTime? ChequeDueDate { get; set; }
    public int? DocumentId { get; set; }
    public DateTime OrderDate { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Main-page daily document row (Accounting / generic daily lists).</summary>
public class DailyDocumentRow
{
    public int DocumentId { get; set; }
    public string DocumentNumber { get; set; } = "";
    public DateTime DocumentDate { get; set; }
    public string? DocumentType { get; set; }
    public string? CounterPartyName { get; set; }
    public decimal TotalAmount { get; set; }
    public string? CurrencyCode { get; set; }
    public string? Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>User row (central) — includes PasswordHash for server-side auth only.</summary>
public class UserRow
{
    public int UserId { get; set; }
    public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";        // PBKDF2 — never exposed to the UI
    public string DisplayName { get; set; } = "";
    public string Role { get; set; } = "";                // نقش (کلید) — برای سازگاری با نسخهٔ قبل
    public int RoleId { get; set; }                       // FK → [central].[Roles]
    public string RoleTitle { get; set; } = "";           // عنوان فارسی نقش
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>Tenant audit row with predecessor metadata; chain correctness is an open release gate.</summary>
/// <remarks>
/// <c>CompanyId == null</c> marks a system-level (central) operation — see
/// docs/adr/ADR-004-auditlog-null-company.md; it must never be backfilled.
/// <c>CompanyName</c> and <c>TotalRows</c> come from AuditSearch.sql.
/// </remarks>
public class AuditRow
{
    public long AuditId { get; set; }
    public int? CompanyId { get; set; }
    public string? CompanyName { get; set; }
    public string PrevHash { get; set; } = "";
    public string RowHash { get; set; } = "";
    public string SchemaName { get; set; } = "";
    public string ScriptName { get; set; } = "";
    public string? UserTokenId { get; set; }
    public string? RequestId { get; set; }
    public string Outcome { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public long TotalRows { get; set; }
}
