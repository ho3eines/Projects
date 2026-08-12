namespace Share;

/// <summary>
/// آدرس پیش‌فرض کلاینت هر محصول + مدل دایرکتوری عمومی پروژه‌ها.
/// منبع حقیقت در دیتابیس فیلد <c>ClientUrl</c> است؛ این ثابت‌ها فقط fallback توسعه هستند.
/// </summary>
public static class HermesApps
{
    public const string Accounting = "https://localhost:65218/";
    public const string Central = "https://localhost:65219/";
    public const string Inventory = "https://localhost:65224/";
    public const string Treasury = "https://localhost:65226/";
    public const string Payroll = "https://localhost:65228/";
    public const string GoldShop = "https://localhost:65230/";
    public const string Store = "https://localhost:65232/";

    public static string ForSchema(string? schema) => (schema ?? "").Trim().ToLowerInvariant() switch
    {
        "accounting" => Accounting,
        "central" => Central,
        "inventory" => Inventory,
        "treasury" => Treasury,
        "payroll" => Payroll,
        "goldshop" => GoldShop,
        "store" => Store,
        _ => ""
    };

    public static string ForName(string? name) => ForSchema(name);

    public static string Open(string baseUrl, string? userToken)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
            return "";
        if (string.IsNullOrWhiteSpace(userToken))
            return baseUrl;
        var sep = baseUrl.Contains('?') ? "&" : "?";
        return baseUrl.TrimEnd('/') + "/" + sep + "token=" + Uri.EscapeDataString(userToken);
    }
}

/// <summary>آیتم عمومی دایرکتوری پروژه‌ها — بدون راز. برای لانچر و لیست ادمین.</summary>
public sealed class ProjectDirectoryItem
{
    public string Name { get; set; } = "";
    public string Schema { get; set; } = "";
    public string ClientUrl { get; set; } = "";
    public string? Icon { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
}
