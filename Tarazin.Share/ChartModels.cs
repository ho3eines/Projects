namespace Tarazin.Models;

// ============================================================
// Models: ماژول «جداول پایه» (Chart of Accounts — چندسطحی)
// Schema: accounting
// جداول:
//   - BaseCol        : حساب کل (2 رقم)
//   - BaseMoein      : حساب معین (3 رقم) — ColId → BaseCol
//   - BaseDetil      : حساب تفصیلی (7 رقم، یکپارچه/Shared)
//   - BaseDetilLink  : محل قرارگیری تفصیلی؛ ParentLinkId سلسله‌مراتب سطح 4+ را می‌سازد
// هر Node در درخت یک مسیر دارد؛ AccountCode = ترکیب کدهای مسیر.
// ============================================================

/// <summary>مقادیر معتبر ماهیت حساب در همهٔ سطوح.</summary>
public static class AccountNatureKind
{
    public const string Debit = "Debit";
    public const string Credit = "Credit";
    public const string Both = "Both";

    public static string Title(string? value) => value switch
    {
        Debit => "بدهکار",
        Credit => "بستانکار",
        Both => "هر دو",
        _ => "—"
    };
}

/// <summary>نوع گروه در ساختار حساب‌ها.</summary>
public static class AccountGroupType
{
    public const string Col = "Col";
    public const string Moein = "Moein";
    public const string Detil = "Detil";

    public static string Title(string? value) => value switch
    {
        Col => "حساب کل",
        Moein => "حساب معین",
        Detil => "حساب تفصیلی",
        _ => "—"
    };
}

/// <summary>
/// گروه حساب. گروه تفصیلی یک بازهٔ ۷ رقمی دارد و شمارهٔ تفصیلی بعدی از همان
/// بازه به‌صورت خودکار تخصیص داده می‌شود.
/// </summary>
public class AccountGroupRow
{
    public int AccountGroupId { get; set; }
    public string GroupType { get; set; } = AccountGroupType.Col;
    public string GroupCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? FromCode { get; set; }
    public string? ToCode { get; set; }
    public string DefaultNature { get; set; } = AccountNatureKind.Both;
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public int AssignedAccountCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>تنظیمات سراسری حسابداری شرکت (گروه‌های تفصیلی مشترک بین ماژول‌ها).</summary>
public class CompanyAccountSettingsRow
{
    public int CompanyId { get; set; }
    public int? CustomerAccountGroupId { get; set; }
    public string? CustomerAccountGroupTitle { get; set; }
    public string? CustomerAccountGroupCode { get; set; }
    public int? SupplierAccountGroupId { get; set; }
    public string? SupplierAccountGroupTitle { get; set; }
    public string? SupplierAccountGroupCode { get; set; }
    public int? InventoryAccountGroupId { get; set; }
    public string? InventoryAccountGroupTitle { get; set; }
    public string? InventoryAccountGroupCode { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>پیش‌نمایش شمارهٔ بعدی قابل تخصیص در یک گروه تفصیلی.</summary>
public class DetilNextCodeRow
{
    public int AccountGroupId { get; set; }
    public string GroupTitle { get; set; } = "";
    public string FromCode { get; set; } = "";
    public string ToCode { get; set; } = "";
    public string? NextCode { get; set; }
    public bool HasCapacity { get; set; }
}

/// <summary>نتیجهٔ ایجاد اتمیک حساب تفصیلی و تخصیص شماره.</summary>
public class BaseDetilCreateResult
{
    public int NewId { get; set; }
    public string DetilCode { get; set; } = "";
}

/// <summary>سطح یک: حساب کل (2 رقم).</summary>
public class BaseColRow
{
    public int ColId { get; set; }
    public string ColCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public int? AccountGroupId { get; set; }
    public string? GroupCode { get; set; }
    public string? GroupTitle { get; set; }
    public string AccountNature { get; set; } = AccountNatureKind.Both;
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
    public int? AccountGroupId { get; set; }
    public string? GroupCode { get; set; }
    public string? GroupTitle { get; set; }
    public string AccountNature { get; set; } = AccountNatureKind.Both;
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
    public int? AccountGroupId { get; set; }
    public string? GroupCode { get; set; }
    public string? GroupTitle { get; set; }
    public string AccountNature { get; set; } = AccountNatureKind.Both;
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>محل قرارگیری Detil در یک مسیر؛ ParentLinkId سطح ۴ به بعد را می‌سازد.</summary>
public class BaseDetilLinkRow
{
    public int LinkId { get; set; }
    public int DetilId { get; set; }
    public int MoeinId { get; set; }
    public int? ParentLinkId { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>یک ردیف درخت حساب‌ها (Chart Tree).</summary>
public class ChartTreeNode
{
    /// <summary>شناسهٔ موجودیت (ColId/MoeinId/DetilId)؛ برای placement تفصیلی LinkId هویت یکتاست.</summary>
    public int NodeId { get; set; }
    public int Level { get; set; }            // 1=کل، 2=معین، 3+=تفصیلی
    public string Code { get; set; } = "";   // کد خود Node
    public string Title { get; set; } = "";
    public string NodeType { get; set; } = "";  // BaseCol | BaseMoein | BaseDetil
    public int? ParentId { get; set; }       // شناسهٔ والد
    /// <summary>کد کامل مسیر (Col + Moein + Detil[...]).</summary>
    public string AccountCode { get; set; } = "";
    public int? AccountGroupId { get; set; }
    public string? GroupCode { get; set; }
    public string? GroupTitle { get; set; }
    public string AccountNature { get; set; } = AccountNatureKind.Both;
    public bool IsActive { get; set; }
    public int ChildCount { get; set; }
    /// <summary>مسیر کامل (Breadcrumb) برای نمایش.</summary>
    public string Breadcrumb { get; set; } = "";

    // برای BaseDetil (وقتی Node یک پیوند به تفصیلی است):
    public int? DetilEntityId { get; set; }
    /// <summary>هویت placement تفصیلی در این مسیر (برای BaseDetil یکتا است).</summary>
    public int? LinkId { get; set; }
    /// <summary>ریشهٔ معین این مسیر.</summary>
    public int? MoeinId { get; set; }
    /// <summary>placement والد؛ NULL برای تفصیلی سطح ۳.</summary>
    public int? ParentLinkId { get; set; }
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
    public int Level { get; set; }
    public int? ParentLinkId { get; set; }
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
