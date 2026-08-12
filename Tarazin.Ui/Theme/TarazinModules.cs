using MudBlazor;

namespace Tarazin.Theme;

public sealed record TarazinModule(
    string Key,
    string Title,
    string Lead,
    string Url,
    string Icon,
    string Accent,
    IReadOnlyList<TarazinNavItem> Items);

public sealed record TarazinNavItem(string Title, string Url, string Icon);

/// <summary>Single catalog for home cards, drawer groups and module sub-nav.</summary>
public static class TarazinModules
{
    public static readonly IReadOnlyList<TarazinModule> All =
    [
        new("central", "پلتفرم مشترک", "اخبار، بلاگ، گالری، کاربران و ممیزی",
            "/central", Icons.Material.Filled.Apartment, "#0E4D4A",
            [
                new("نمای کلی", "/central", Icons.Material.Filled.Home),
                new("اخبار", "/central/news", Icons.Material.Filled.Newspaper),
                new("وبلاگ", "/central/blog", Icons.Material.Filled.EditNote),
                new("گالری", "/central/gallery", Icons.Material.Filled.PhotoLibrary),
                new("کاربران", "/central/users", Icons.Material.Filled.Group),
                new("ممیزی", "/central/audit", Icons.Material.Filled.Policy),
            ]),
        new("accounting", "حسابداری", "اسناد روز، دفتر روزنامه و کل، تراز آزمایشی",
            "/accounting", Icons.Material.Filled.AccountBalance, "#1E4B73",
            [
                new("داشبورد", "/accounting/dashboard", Icons.Material.Filled.Dashboard),
                new("اسناد روز", "/accounting", Icons.Material.Filled.Today),
                new("ثبت سند", "/accounting/entry", Icons.Material.Filled.PostAdd),
                new("عملیات ویژه", "/accounting/special", Icons.Material.Filled.AutoFixHigh),
                new("گزارشات", "/accounting/reports", Icons.Material.Filled.Assessment),
                new("امکانات", "/accounting/settings", Icons.Material.Filled.Tune),
            ]),
        new("inventory", "انبار آمل", "رسید و حواله، کارتکس، موجودی کالا",
            "/inventory", Icons.Material.Filled.Inventory2, "#4A6B3A",
            [
                new("داشبورد", "/inventory/dashboard", Icons.Material.Filled.Dashboard),
                new("اسناد روز", "/inventory", Icons.Material.Filled.Today),
                new("حرکت جدید", "/inventory/entry", Icons.Material.Filled.MoveUp),
                new("عملیات ویژه", "/inventory/special", Icons.Material.Filled.AutoFixHigh),
                new("گزارشات", "/inventory/reports", Icons.Material.Filled.Assessment),
                new("امکانات", "/inventory/settings", Icons.Material.Filled.Tune),
            ]),
        new("treasury", "خزانه‌داری", "دریافت و پرداخت، صندوق و بانک، چک",
            "/treasury", Icons.Material.Filled.AccountBalanceWallet, "#C49A3C",
            [
                new("داشبورد", "/treasury/dashboard", Icons.Material.Filled.Dashboard),
                new("گردش روز", "/treasury", Icons.Material.Filled.Today),
                new("دریافت / پرداخت", "/treasury/entry", Icons.Material.Filled.SwapHoriz),
                new("بستن روز", "/treasury/special", Icons.Material.Filled.LockClock),
                new("گزارشات", "/treasury/reports", Icons.Material.Filled.Assessment),
                new("امکانات", "/treasury/settings", Icons.Material.Filled.Tune),
            ]),
        new("payroll", "حقوق و دستمزد", "کارمندان، فیش حقوق، نهایی‌کردن دوره",
            "/payroll", Icons.Material.Filled.Badge, "#9C3B2E",
            [
                new("داشبورد", "/payroll/dashboard", Icons.Material.Filled.Dashboard),
                new("دوره‌ها", "/payroll", Icons.Material.Filled.Today),
                new("فیش حقوق", "/payroll/entry", Icons.Material.Filled.ReceiptLong),
                new("نهایی‌کردن", "/payroll/special", Icons.Material.Filled.DoneAll),
                new("گزارشات", "/payroll/reports", Icons.Material.Filled.Assessment),
                new("امکانات", "/payroll/settings", Icons.Material.Filled.Tune),
            ]),
        new("goldshop", "طلافروشی", "فروش روز، قیمت طلا، فاکتور و اجناس",
            "/goldshop", Icons.Material.Filled.Diamond, "#B8860B",
            [
                new("داشبورد", "/goldshop/dashboard", Icons.Material.Filled.Dashboard),
                new("فروش روز", "/goldshop", Icons.Material.Filled.Today),
                new("فاکتور فروش", "/goldshop/entry", Icons.Material.Filled.PointOfSale),
                new("قیمت طلا", "/goldshop/special", Icons.Material.Filled.ShowChart),
                new("گزارشات", "/goldshop/reports", Icons.Material.Filled.Assessment),
                new("امکانات", "/goldshop/settings", Icons.Material.Filled.Tune),
            ]),
        new("store", "فروشگاه", "سفارش‌ها، محصولات و مشتریان",
            "/store", Icons.Material.Filled.Storefront, "#2B6B7A",
            [
                new("داشبورد", "/store/dashboard", Icons.Material.Filled.Dashboard),
                new("سفارش‌های روز", "/store", Icons.Material.Filled.Today),
                new("ثبت سفارش", "/store/entry", Icons.Material.Filled.AddShoppingCart),
                new("عملیات ویژه", "/store/special", Icons.Material.Filled.AutoFixHigh),
                new("گزارشات", "/store/reports", Icons.Material.Filled.Assessment),
                new("امکانات", "/store/settings", Icons.Material.Filled.Tune),
            ]),
    ];

    public static TarazinModule? Match(string relativePath)
    {
        var path = (relativePath ?? "").Trim().Trim('/').ToLowerInvariant();
        if (string.IsNullOrEmpty(path) || path is "login" or "diag")
            return null;
        var key = path.Split('/', 2)[0];
        return All.FirstOrDefault(m => m.Key == key);
    }

    public static bool IsActive(string currentPath, string href)
    {
        var cur = "/" + (currentPath ?? "").Trim().Trim('/').ToLowerInvariant();
        var target = "/" + (href ?? "").Trim().Trim('/').ToLowerInvariant();
        if (cur == "/") return target == "/";
        if (target == "/") return cur == "/";
        if (cur == target) return true;
        // Root of a module must not stay active on child pages.
        var isModuleRoot = All.Any(m => string.Equals(m.Url, target, StringComparison.OrdinalIgnoreCase));
        return !isModuleRoot && cur.StartsWith(target + "/", StringComparison.OrdinalIgnoreCase);
    }
}
