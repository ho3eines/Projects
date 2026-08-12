namespace HermesApp.Models;

/// <summary>اخبار شرکت (ماژول پلتفرم مشترک / وبسایت).</summary>
public class NewsRow
{
    public int NewsId { get; set; }
    public string Title { get; set; } = "";
    public string? Summary { get; set; }
    public string? ImageUrl { get; set; }
    public DateTime? PublishedAt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

/// <summary>پست وبلاگ (پلتفرم مشترک / وبسایت).</summary>
public class BlogRow
{
    public int PostId { get; set; }
    public string Title { get; set; } = "";
    public string? Slug { get; set; }
    public string? Author { get; set; }
    public string? Tags { get; set; }
    public DateTime? PublishedAt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
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
}
