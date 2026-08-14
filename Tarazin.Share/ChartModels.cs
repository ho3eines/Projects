namespace Tarazin.Models;

// ============================================================
// Models: ماژول «جداول پایه» (Chart of Accounts — سه‌سطحی)
// Schema: accounting
// جداول:
//   - BaseCol        : حساب کل (2 رقم)
//   - BaseMoein      : حساب معین (3 رقم) — ColId → BaseCol
//   - BaseDetil      : حساب تفصیلی (7 رقم، یکپارچه/Shared)
//   - BaseDetilLink  : پیوند N-بین-M بین BaseDetil و BaseMoein
// هر Node در درخت یک مسیر دارد؛ AccountCode = ترکیب کدهای مسیر.
// ============================================================

/// <summary>سطح یک: حساب کل (2 رقم).</summary>
public class BaseColRow
{
    public int ColId { get; set; }
    public string ColCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>سطح دو: حساب معین (3 رقم) — زیرمجموعهٔ BaseCol.</summary>
public class BaseMoeinRow
{
    public int MoeinId { get; set; }
    public int ColId { get; set; }
    public string MoeinCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>سطح سه به بعد: حساب تفصیلی یکپارچه (7 رقم، Shared).</summary>
public class BaseDetilRow
{
    public int DetilId { get; set; }
    public string DetilCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>پیوند بین Detil و Moein — یک Detil می‌تواند در چند مسیر باشد.</summary>
public class BaseDetilLinkRow
{
    public int LinkId { get; set; }
    public int DetilId { get; set; }
    public int MoeinId { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>یک ردیف درخت حساب‌ها (Chart Tree).</summary>
public class ChartTreeNode
{
    /// <summary>شناسهٔ منحصربه‌فرد Node (ColId/MoeinId/DetilId).</summary>
    public int NodeId { get; set; }
    public int Level { get; set; }            // 1=کل، 2=معین، 3=تفصیلی
    public string Code { get; set; } = "";   // کد خود Node
    public string Title { get; set; } = "";
    public string NodeType { get; set; } = "";  // BaseCol | BaseMoein | BaseDetil
    public int? ParentId { get; set; }       // شناسهٔ والد
    /// <summary>کد کامل مسیر (Col + Moein + Detil[...]).</summary>
    public string AccountCode { get; set; } = "";
    public bool IsActive { get; set; }
    public int ChildCount { get; set; }
    /// <summary>مسیر کامل (Breadcrumb) برای نمایش.</summary>
    public string Breadcrumb { get; set; } = "";

    // برای BaseDetil (وقتی Node یک پیوند به تفصیلی است):
    public int? DetilEntityId { get; set; }
    public int? LinkId { get; set; }
    public int? MoeinId { get; set; }
}

/// <summary>یک مرحله از مسیر (Breadcrumb) برای نمایش.</summary>
public class ChartBreadcrumbRow
{
    public int NodeId { get; set; }
    public int Level { get; set; }
    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public bool IsActive { get; set; }
    public string NodeType { get; set; } = "";
    public int? ParentId { get; set; }
    public string AccountCode { get; set; } = "";
}

/// <summary>یک مسیر استفاده از تفصیلی.</summary>
public class BaseDetilUsagePath
{
    public int LinkId { get; set; }
    public int MoeinId { get; set; }
    public int DetilId { get; set; }
    public int ColId { get; set; }
    public string ColCode { get; set; } = "";
    public string ColTitle { get; set; } = "";
    public string MoeinCode { get; set; } = "";
    public string MoeinTitle { get; set; } = "";
    public string DetilCode { get; set; } = "";
    public string DetilTitle { get; set; } = "";
    public string AccountCode { get; set; } = "";
    public string PathTitle { get; set; } = "";
    public bool LinkIsActive { get; set; }
}
