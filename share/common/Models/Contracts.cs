namespace Share.Models;

// ============================================================
// Shared domain contracts (PRD §3, ADR-003).
// Column aliases in named scripts MUST match these property names.
// ============================================================

/// <summary>Contract: Party (Core) — v2 (adds NationalId; v1 = PartySearch_V1).</summary>
public class PartyRow
{
    public int PartyId { get; set; }
    public string PartyCode { get; set; } = "";
    public string PartyType { get; set; } = "";        // Customer | Vendor | Employee
    public string FullName { get; set; } = "";
    public string? NationalId { get; set; }             // v2
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>Contract: ChartOfAccount (Accounting).</summary>
public class ChartOfAccountRow
{
    public int AccountId { get; set; }
    public string AccountCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? AccountType { get; set; }            // Asset | Liability | Equity | Income | Expense
    public int? ParentAccountId { get; set; }
    public bool IsActive { get; set; }
}

/// <summary>Contract: CurrencyRate (Treasury).</summary>
public class CurrencyRateRow
{
    public int RateId { get; set; }
    public string CurrencyCode { get; set; } = "";      // IRR | USD | EUR | XAU
    public string CurrencyName { get; set; } = "";
    public decimal RateToIRR { get; set; }
    public DateTime RateDate { get; set; }
    public DateTime UpdatedAt { get; set; }
}

/// <summary>Contract: TaxRule (Accounting).</summary>
public class TaxRuleRow
{
    public int TaxRuleId { get; set; }
    public string RuleCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Category { get; set; }               // Vat | Payroll | Gold | Commerce
    public decimal RatePercent { get; set; }
    public DateTime EffectiveFrom { get; set; }
    public bool IsActive { get; set; }
}

/// <summary>Contract: InventoryMovement (Warehouse).</summary>
public class InventoryMovementRow
{
    public int MovementId { get; set; }
    public string MovementNumber { get; set; } = "";
    public string MovementType { get; set; } = "";      // Receipt | Issue | Adjustment
    public int ItemId { get; set; }
    public string ItemCode { get; set; } = "";
    public string ItemTitle { get; set; } = "";
    public decimal Qty { get; set; }
    public decimal UnitPrice { get; set; }
    public DateTime MovementDate { get; set; }
}

/// <summary>Contract: PayrollRun (Payroll).</summary>
public class PayrollRunRow
{
    public int RunId { get; set; }
    public string Period { get; set; } = "";            // e.g. 1405-05
    public int EmployeeCount { get; set; }
    public decimal NetTotal { get; set; }
    public string Status { get; set; } = "";            // Draft | Finalized | Posted
    public DateTime CreatedAt { get; set; }
}

/// <summary>Contract: GoldPrice (GoldShop).</summary>
public class GoldPriceRow
{
    public int PriceId { get; set; }
    public string ItemCode { get; set; } = "";          // e.g. XAU-24, SIKKEH-EMAMI
    public string Title { get; set; } = "";
    public decimal PricePerGram { get; set; }           // IRR per gram
    public decimal? RateToIRR { get; set; }             // optional FX reference
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
    public string Status { get; set; } = "";            // Placed | Reserved | Invoiced | Rejected | Cancelled
    public DateTime OrderDate { get; set; }
}
