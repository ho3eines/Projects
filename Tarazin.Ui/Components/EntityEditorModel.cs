using Tarazin.Models;

namespace Tarazin.Components;

/// <summary>
/// مدل مشترک فرم‌های «جدید/ویرایش». مقدار صفر شناسه همیشه به معنی رکورد جدید است.
/// این مدل باعث می‌شود همهٔ جداول پایه از یک الگوی یکسان MudDialog استفاده کنند.
/// </summary>
public sealed class EntityEditorModel
{
    public EntityEditorKind Kind { get; init; }
    public int Id { get; init; }
    public bool IsNew => Id == 0;

    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public string Text { get; set; } = "";
    public string ExtraText { get; set; } = "";
    public string Tags { get; set; } = "";
    public string Body { get; set; } = "";
    public string ImageUrl { get; set; } = "";
    public string Password { get; set; } = "";
    public DateTime? Date { get; set; }
    public decimal? Amount { get; set; }
    public decimal? SecondaryAmount { get; set; }
    public int SortOrder { get; set; }
    public int? ParentId { get; set; }
    public bool IsActive { get; set; } = true;

    public string DialogTitle => $"{(IsNew ? "ایجاد" : "ویرایش")} {EntityTitle}";
    public string DisplayLabel => string.IsNullOrWhiteSpace(Title) ? Code : Title;

    public string EntityTitle => Kind switch
    {
        EntityEditorKind.News => "خبر",
        EntityEditorKind.Blog => "پست وبلاگ",
        EntityEditorKind.Gallery => "آیتم گالری",
        EntityEditorKind.User => "کاربر",
        EntityEditorKind.Account => "حساب",
        EntityEditorKind.GoldItem => "جنس طلا",
        EntityEditorKind.GoldPrice => "قیمت طلا",
        EntityEditorKind.InventoryItem => "کالا",
        EntityEditorKind.Warehouse => "انبار",
        EntityEditorKind.Employee => "کارمند",
        EntityEditorKind.Product => "محصول",
        EntityEditorKind.Customer => "مشتری",
        EntityEditorKind.CurrencyRate => "نرخ ارز",
        _ => "رکورد"
    };

    public static EntityEditorModel FromNews(NewsRow? row = null) => new()
    {
        Kind = EntityEditorKind.News,
        Id = row?.NewsId ?? 0,
        Title = row?.Title ?? "",
        Text = row?.Summary ?? "",
        Body = row?.Body ?? "",
        ImageUrl = row?.ImageUrl ?? "",
        Date = row?.PublishedAt ?? DateTime.Today,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromBlog(BlogRow? row = null) => new()
    {
        Kind = EntityEditorKind.Blog,
        Id = row?.PostId ?? 0,
        Code = row?.Slug ?? "",
        Title = row?.Title ?? "",
        Text = row?.Author ?? "",
        Tags = row?.Tags ?? "",
        Body = row?.Body ?? "",
        Date = row?.PublishedAt ?? DateTime.Today,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromGallery(GalleryItemRow? row = null, int nextSortOrder = 0) => new()
    {
        Kind = EntityEditorKind.Gallery,
        Id = row?.GalleryItemId ?? 0,
        Title = row?.Title ?? "",
        Text = row?.Caption ?? "",
        ImageUrl = row?.ImageUrl ?? "",
        SortOrder = row?.SortOrder ?? nextSortOrder,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromUser(UserRow? row = null) => new()
    {
        Kind = EntityEditorKind.User,
        Id = row?.UserId ?? 0,
        Code = row?.Username ?? "",
        Title = row?.DisplayName ?? "",
        Text = row?.Role ?? "User",
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromAccount(ChartOfAccountRow? row = null) => new()
    {
        Kind = EntityEditorKind.Account,
        Id = row?.AccountId ?? 0,
        Code = row?.AccountCode ?? "",
        Title = row?.Title ?? "",
        Text = row?.AccountType ?? "",
        ParentId = row?.ParentAccountId,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromGoldItem(GoldItemRow? row = null) => new()
    {
        Kind = EntityEditorKind.GoldItem,
        Id = row?.GoldItemId ?? 0,
        Code = row?.ItemCode ?? "",
        Title = row?.Title ?? "",
        Amount = row?.Purity,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromGoldPrice(GoldPriceRow? row = null) => new()
    {
        Kind = EntityEditorKind.GoldPrice,
        Id = row?.PriceId ?? 0,
        Code = row?.ItemCode ?? "",
        Title = row?.Title ?? "",
        Amount = row?.PricePerGram ?? 0,
        SecondaryAmount = row?.RateToIRR,
        IsActive = true
    };

    public static EntityEditorModel FromInventoryItem(ItemRow? row = null) => new()
    {
        Kind = EntityEditorKind.InventoryItem,
        Id = row?.ItemId ?? 0,
        Code = row?.ItemCode ?? "",
        Title = row?.ItemTitle ?? "",
        Text = row?.Category ?? "",
        ExtraText = row?.Unit ?? "عدد",
        Amount = row?.UnitPrice ?? 0,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromWarehouse(WarehouseRow? row = null) => new()
    {
        Kind = EntityEditorKind.Warehouse,
        Id = row?.WarehouseId ?? 0,
        Code = row?.WarehouseCode ?? "",
        Title = row?.Title ?? "",
        Text = row?.Location ?? "",
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromEmployee(EmployeeRow? row = null) => new()
    {
        Kind = EntityEditorKind.Employee,
        Id = row?.EmployeeId ?? 0,
        Code = row?.EmployeeCode ?? "",
        Title = row?.FullName ?? "",
        Text = row?.Department ?? "",
        ExtraText = row?.NationalId ?? "",
        Amount = row?.BaseSalary ?? 0,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromProduct(ProductRow? row = null) => new()
    {
        Kind = EntityEditorKind.Product,
        Id = row?.ProductId ?? 0,
        Code = row?.ProductCode ?? "",
        Title = row?.Title ?? "",
        ExtraText = row?.ItemCode ?? "",
        Amount = row?.Price ?? 0,
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromCustomer(CustomerRow? row = null) => new()
    {
        Kind = EntityEditorKind.Customer,
        Id = row?.CustomerId ?? 0,
        Code = row?.CustomerCode ?? "",
        Title = row?.FullName ?? "",
        Text = row?.Phone ?? "",
        ExtraText = row?.Email ?? "",
        IsActive = row?.IsActive ?? true
    };

    public static EntityEditorModel FromCurrencyRate(CurrencyRateRow? row = null) => new()
    {
        Kind = EntityEditorKind.CurrencyRate,
        Id = row?.RateId ?? 0,
        Code = row?.CurrencyCode ?? "",
        Title = row?.CurrencyName ?? "",
        Amount = row?.RateToIRR ?? 0,
        Date = row?.RateDate ?? DateTime.Today,
        IsActive = true
    };
}

public enum EntityEditorKind
{
    News,
    Blog,
    Gallery,
    User,
    Account,
    GoldItem,
    GoldPrice,
    InventoryItem,
    Warehouse,
    Employee,
    Product,
    Customer,
    CurrencyRate
}
