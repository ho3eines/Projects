namespace Tarazin.Models;

// ============================================================
// اموال و دارایی ثابت — PRD BI §73/§74.
// ستون‌های اسکریپت‌های نامدار باید با همین نام‌ها هم‌نام باشند (ADR-003).
// ============================================================

/// <summary>Contract: FixedAsset (اموال و دارایی ثابت).</summary>
public class FixedAssetRow
{
    public int AssetId { get; set; }
    public string AssetCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Category { get; set; }
    public DateTime PurchaseDate { get; set; }
    public decimal PurchaseCost { get; set; }
    public int UsefulLifeMonths { get; set; }
    public decimal ResidualValue { get; set; }
    public string Status { get; set; } = "Active";       // Active | Scrapped | Transferred
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }

    // محاسباتی (در FixedAssetList)
    public decimal MonthlyDepreciation { get; set; }
    public decimal AccumulatedDepreciation { get; set; }
    public decimal NetBookValue { get; set; }
}

/// <summary>Contract: Branch (شعبه).</summary>
public class BranchRow
{
    public int BranchId { get; set; }
    public string BranchCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Location { get; set; }
    public string? Manager { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}
