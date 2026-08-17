namespace Tarazin.Models;

/// <summary>اخبار شرکت (ماژول پلتفرم مشترک / وبسایت).</summary>
public class NewsRow
{
    public int NewsId { get; set; }
    public string Title { get; set; } = "";
    public string? Summary { get; set; }
    public string? Body { get; set; }
    public string? ImageUrl { get; set; }
    public DateTime? PublishedAt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>پست وبلاگ (پلتفرم مشترک / وبسایت).</summary>
public class BlogRow
{
    public int PostId { get; set; }
    public string Title { get; set; } = "";
    public string? Slug { get; set; }
    public string? Body { get; set; }
    public string? Author { get; set; }
    public string? Tags { get; set; }
    public DateTime? PublishedAt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>آیتم گالری (پلتفرم مشترک / وبسایت).</summary>
public class GalleryItemRow
{
    public int GalleryItemId { get; set; }
    public string Title { get; set; } = "";
    public string? ImageUrl { get; set; }
    public string? Caption { get; set; }
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>شرکت مالی</summary>
public class CompanyRow
{
    public int CompanyId { get; set; }
    public string CompanyName { get; set; } = "";
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
}

/// <summary>سال مالی</summary>
public class FiscalYearRow
{
    public int FiscalYearId { get; set; }
    public int CompanyId { get; set; }
    public string CompanyName { get; set; } = "";
    public string YearName { get; set; } = "";
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool IsActive { get; set; }
    /// <summary>چرخهٔ حیات سال مالی: Open | Closed.</summary>
    public string Status { get; set; } = FiscalYearStatus.Open;
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }

    public bool IsClosed => string.Equals(Status, FiscalYearStatus.Closed, StringComparison.OrdinalIgnoreCase);
}

/// <summary>مقادیر معتبر چرخهٔ حیات سال مالی.</summary>
public static class FiscalYearStatus
{
    public const string Open = "Open";
    public const string Closed = "Closed";
}

/// <summary>محیط فعال کاربر</summary>
public class UserActiveContextRow
{
    public int? ActiveCompanyId { get; set; }
    public string? ActiveCompanyName { get; set; }
    public int? ActiveFiscalYearId { get; set; }
    public string? ActiveFiscalYearName { get; set; }
}
