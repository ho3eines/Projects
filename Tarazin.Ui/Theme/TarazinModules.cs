using MudBlazor;
using Tarazin.Models;

namespace Tarazin.Theme;

public sealed record TarazinModule(
    string Key,
    string Title,
    string Lead,
    string Url,
    string Icon,
    string Accent,
    IReadOnlyList<TarazinNavItem> Items);

/// <param name="Permission">کلید دسترسی لازم برای نمایش/باز کردن این صفحه (RBAC).</param>
/// <param name="HideInNav">
/// صفحه‌هایی که از داخل صفحات دیگر باز می‌شوند (مثل جزئیات یک سند) و نباید در
/// منو/زیرمنو دیده شوند، ولی باید در گاردِ دسترسیِ مسیر لحاظ شوند.
/// </param>
public sealed record TarazinNavItem(string Title, string Url, string Icon, string Permission,
    bool HideInNav = false);

/// <summary>Single catalog for home cards, drawer groups and module sub-nav.</summary>
public static class TarazinModules
{
    public static readonly IReadOnlyList<TarazinModule> All =
    [
        new("central", "پلتفرم مشترک", "اخبار، بلاگ، گالری، کاربران، نقش‌ها و ممیزی",
            "/central", Icons.Material.Filled.Apartment, TarazinAccents.Ink,
            [
                new("نمای کلی", "/central", Icons.Material.Filled.Home, Perm("central", TarazinActions.View)),
                new("اخبار", "/central/news", Icons.Material.Filled.Newspaper, Perm("central", TarazinActions.View)),
                new("وبلاگ", "/central/blog", Icons.Material.Filled.EditNote, Perm("central", TarazinActions.View)),
                new("گالری", "/central/gallery", Icons.Material.Filled.PhotoLibrary, Perm("central", TarazinActions.View)),
                new("کاربران", "/central/users", Icons.Material.Filled.Group, TarazinPermissions.Users),
                new("نقش‌ها و دسترسی‌ها", "/central/roles", Icons.Material.Filled.AdminPanelSettings, TarazinPermissions.Roles),
                new("ممیزی", "/central/audit", Icons.Material.Filled.Policy, TarazinPermissions.Audit),
                new("مدیریت قالب‌های چاپ", "/central/printing", Icons.Material.Filled.Print, Perm("central", TarazinActions.View)),
                new("سلامت ربات تلگرام", "/central/telegram-bot", Icons.Material.Filled.SmartToy, Perm("central", TarazinActions.View)),
            ]),
        new("accounting", "حسابداری", "اسناد، دفتر روزنامه و کل، تراز آزمایشی",
            "/accounting", Icons.Material.Filled.AccountBalance, TarazinAccents.Steel,
            [
                new("داشبورد", "/accounting/dashboard", Icons.Material.Filled.Dashboard, Perm("accounting", TarazinActions.View)),
                new("اسناد", "/accounting", Icons.Material.Filled.Description, Perm("accounting", TarazinActions.View)),
                new("ماندهٔ ابتدای دوره", "/accounting/opening", Icons.Material.Filled.Balance, Perm("accounting", TarazinActions.Entry)),
                new("ثبت سند", "/accounting/entry", Icons.Material.Filled.PostAdd, Perm("accounting", TarazinActions.Entry)),
                // صفحهٔ سند از فهرست اسناد باز می‌شود و در زیرمنو تکرار نمی‌شود؛
                // اما باید در گاردِ مسیر شناخته شود تا با «مشاهدهٔ حسابداری» محافظت شود.
                new("سند حسابداری", "/accounting/document", Icons.Material.Filled.Description, Perm("accounting", TarazinActions.View), HideInNav: true),
                new("جداول پایه", "/accounting/chart", Icons.Material.Filled.AccountTree, TarazinPermissions.ChartView),
                new("عملیات ویژه", "/accounting/special", Icons.Material.Filled.AutoFixHigh, Perm("accounting", TarazinActions.Special)),
                new("گزارشات", "/accounting/reports", Icons.Material.Filled.Assessment, Perm("accounting", TarazinActions.Reports)),
                new("قوانین مالیاتی", "/accounting/tax-rules", Icons.Material.Filled.RequestQuote, Perm("accounting", TarazinActions.Settings)),
                new("تنظیمات شرکت", "/accounting/settings", Icons.Material.Filled.CorporateFare, Perm("accounting", TarazinActions.Settings)),
            ]),
        new("inventory", "انبار", "رسید و حواله، کارتکس، موجودی کالا",
            "/inventory", Icons.Material.Filled.Inventory2, TarazinAccents.Moss,
            [
                new("داشبورد", "/inventory/dashboard", Icons.Material.Filled.Dashboard, Perm("inventory", TarazinActions.View)),
                new("اسناد روز", "/inventory", Icons.Material.Filled.Today, Perm("inventory", TarazinActions.View)),
                new("انبارها", "/inventory/warehouses", Icons.Material.Filled.Inventory2, Perm("inventory", TarazinActions.View)),
                new("کالاها", "/inventory/items", Icons.Material.Filled.Inventory, Perm("inventory", TarazinActions.View)),
                new("فاکتور خرید", "/inventory/purchase-invoice", Icons.Material.Filled.ShoppingCartCheckout, TarazinPermissions.InventoryPurchase),
                new("لیست فاکتورهای خرید", "/inventory/purchase-invoices", Icons.Material.Filled.ReceiptLong, TarazinPermissions.InventoryPurchase),
                new("فاکتور فروش", "/inventory/sales-invoice", Icons.Material.Filled.PointOfSale, TarazinPermissions.InventorySales),
                new("لیست فاکتورهای فروش", "/inventory/sales-invoices", Icons.Material.Filled.Receipt, TarazinPermissions.InventorySales),
                new("انتقال بین انبارها", "/inventory/transfer", Icons.Material.Filled.SwapHoriz, TarazinPermissions.InventoryTransfer),
                new("برگشت خرید", "/inventory/purchase-return", Icons.Material.Filled.Undo, TarazinPermissions.InventoryPurchaseReturn),
                new("برگشت فروش", "/inventory/sales-return", Icons.Material.Filled.Replay, TarazinPermissions.InventorySalesReturn),
                new("عملیات ویژه", "/inventory/special", Icons.Material.Filled.AutoFixHigh, Perm("inventory", TarazinActions.Special)),
                new("گزارشات", "/inventory/reports", Icons.Material.Filled.Assessment, Perm("inventory", TarazinActions.Reports)),
                new("امکانات", "/inventory/settings", Icons.Material.Filled.Tune, Perm("inventory", TarazinActions.Settings)),
            ]),
        new("treasury", "خزانه‌داری", "دریافت و پرداخت، صندوق و بانک، چک",
            "/treasury", Icons.Material.Filled.AccountBalanceWallet, TarazinAccents.Gold,
            [
                new("داشبورد", "/treasury/dashboard", Icons.Material.Filled.Dashboard, Perm("treasury", TarazinActions.View)),
                new("گردش روز", "/treasury", Icons.Material.Filled.Today, Perm("treasury", TarazinActions.View)),
                new("دریافت / پرداخت", "/treasury/entry", Icons.Material.Filled.SwapHoriz, Perm("treasury", TarazinActions.Entry)),
                new("مشتریان و تأمین‌کنندگان", "/treasury/parties", Icons.Material.Filled.People, Perm("treasury", TarazinActions.View)),
                new("چک‌ها", "/treasury/cheques", Icons.Material.Filled.ReceiptLong, Perm("treasury", TarazinActions.Entry)),
                new("گزارش چک‌ها", "/treasury/cheque-report", Icons.Material.Filled.NotificationsActive, Perm("treasury", TarazinActions.Reports)),
                new("بستن روز", "/treasury/special", Icons.Material.Filled.LockClock, Perm("treasury", TarazinActions.Special)),
                new("گزارشات", "/treasury/reports", Icons.Material.Filled.Assessment, Perm("treasury", TarazinActions.Reports)),
                new("امکانات", "/treasury/settings", Icons.Material.Filled.Tune, Perm("treasury", TarazinActions.Settings)),
            ]),
        new("payroll", "حقوق و دستمزد", "کارمندان، حکم اداری، فیش حقوق، ماه جاری",
            "/payroll", Icons.Material.Filled.Badge, TarazinAccents.Wine,
            [
                new("داشبورد", "/payroll/dashboard", Icons.Material.Filled.Dashboard, Perm("payroll", TarazinActions.View)),
                new("ماه جاری", "/payroll/special", Icons.Material.Filled.CalendarMonth, Perm("payroll", TarazinActions.Special)),
                new("دوره‌ها", "/payroll", Icons.Material.Filled.History, Perm("payroll", TarazinActions.View)),
                new("فیش حقوق", "/payroll/entry", Icons.Material.Filled.ReceiptLong, Perm("payroll", TarazinActions.Entry)),
                new("اقلام حقوق", "/payroll/salaryitems", Icons.Material.Filled.PostAdd, Perm("payroll", TarazinActions.Entry)),
                new("حضورغیاب", "/payroll/attendance", Icons.Material.Filled.Schedule, Perm("payroll", TarazinActions.Entry)),
                new("گزارشات", "/payroll/reports", Icons.Material.Filled.Assessment, Perm("payroll", TarazinActions.Reports)),
                new("امکانات", "/payroll/settings", Icons.Material.Filled.Tune, Perm("payroll", TarazinActions.Settings)),
            ]),
        new("goldshop", "طلافروشی", "فروش روز، قیمت طلا، فاکتور و اجناس",
            "/goldshop", Icons.Material.Filled.Diamond, TarazinAccents.Brass,
            [
                new("داشبورد", "/goldshop/dashboard", Icons.Material.Filled.Dashboard, Perm("goldshop", TarazinActions.View)),
                new("فروش روز", "/goldshop", Icons.Material.Filled.Today, Perm("goldshop", TarazinActions.View)),
                new("فاکتور فروش", "/goldshop/entry", Icons.Material.Filled.PointOfSale, Perm("goldshop", TarazinActions.Entry)),
                new("مشتریان و تأمین‌کنندگان", "/goldshop/parties", Icons.Material.Filled.People, Perm("goldshop", TarazinActions.View)),
                new("قیمت طلا", "/goldshop/special", Icons.Material.Filled.ShowChart, Perm("goldshop", TarazinActions.Special)),
                new("گزارشات", "/goldshop/reports", Icons.Material.Filled.Assessment, Perm("goldshop", TarazinActions.Reports)),
                new("اتصال انبار و حسابداری", "/goldshop/settings/integration", Icons.Material.Filled.Link, Perm("goldshop", TarazinActions.Settings)),
            ]),
        new("currency", "ارز و معاملات ارزی", "کیف پول ارز، خرید و فروش، تبدیل، مرکز نرخ‌ها و ارزش لحظه‌ای دارایی",
            "/currency", Icons.Material.Filled.Payments, TarazinAccents.Emerald,
            [
                new("تابلو قیمت", "/currency", Icons.Material.Filled.Dashboard, Perm("currency", TarazinActions.View)),
                new("داشبورد ارز", "/currency/dashboard", Icons.Material.Filled.Insights, Perm("currency", TarazinActions.View)),
                new("کیف پول‌ها", "/currency/wallets", Icons.Material.Filled.AccountBalanceWallet, Perm("currency", TarazinActions.View)),
                new("خرید / فروش ارز", "/currency/entry", Icons.Material.Filled.SwapHoriz, Perm("currency", TarazinActions.Entry)),
                new("معامله ترکیبی", "/currency/combined", Icons.Material.Filled.CallMerge, Perm("currency", TarazinActions.Entry)),
                new("تبدیل ارز", "/currency/convert", Icons.Material.Filled.SwapCalls, Perm("currency", TarazinActions.Entry)),
                new("مرکز نرخ‌ها و قیمت‌ها", "/currency/prices", Icons.Material.Filled.ShowChart, TarazinPermissions.RateView),
                new("ارزش لحظه‌ای دارایی", "/currency/assets", Icons.Material.Filled.DonutLarge, Perm("currency", TarazinActions.View)),
                new("عملیات ویژه", "/currency/special", Icons.Material.Filled.AutoFixHigh, Perm("currency", TarazinActions.Special)),
                new("گزارشات", "/currency/reports", Icons.Material.Filled.Assessment, Perm("currency", TarazinActions.Reports)),
                new("امکانات", "/currency/settings", Icons.Material.Filled.Tune, Perm("currency", TarazinActions.Settings)),
            ]),
        new("bi", "داشبورد و BI", "مرکز فرماندهی: اجرایی، مالی، خزانه، فروش، طلا، ارز، انبار، هشدار و تحلیل هوشمند",
            "/bi", Icons.Material.Filled.SpaceDashboard, TarazinAccents.Violet,
            [
                new("مرکز فرماندهی", "/bi", Icons.Material.Filled.SpaceDashboard, Perm("bi", TarazinActions.View)),
                new("هشدارها", "/bi/alerts", Icons.Material.Filled.NotificationsActive, Perm("bi", TarazinActions.View)),
                new("گزارش‌ها", "/bi/reports", Icons.Material.Filled.Print, Perm("bi", TarazinActions.Reports)),
                new("اموال و دارایی ثابت", "/bi/assets", Icons.Material.Filled.HomeWork, Perm("assets", TarazinActions.View)),
                new("شعب", "/bi/branches", Icons.Material.Filled.Apartment, Perm("branch", TarazinActions.View)),
            ]),
        new("store", "فروشگاه", "سفارش‌ها، محصولات و مشتریان",
            "/store", Icons.Material.Filled.Storefront, TarazinAccents.Petrol,
            [
                new("داشبورد", "/store/dashboard", Icons.Material.Filled.Dashboard, Perm("store", TarazinActions.View)),
                new("سفارش‌های روز", "/store", Icons.Material.Filled.Today, Perm("store", TarazinActions.View)),
                new("ثبت سفارش", "/store/entry", Icons.Material.Filled.AddShoppingCart, Perm("store", TarazinActions.Entry)),
                new("عملیات ویژه", "/store/special", Icons.Material.Filled.AutoFixHigh, Perm("store", TarazinActions.Special)),
                new("گزارشات", "/store/reports", Icons.Material.Filled.Assessment, Perm("store", TarazinActions.Reports)),
                new("امکانات", "/store/settings", Icons.Material.Filled.Tune, Perm("store", TarazinActions.Settings)),
            ]),
    ];

    private static string Perm(string module, string action) => TarazinPermissions.For(module, action);

    private static string NormalizeRelativePath(string? relativePath)
    {
        var value = (relativePath ?? "").Trim();
        var suffix = value.IndexOfAny(['?', '#']);
        if (suffix >= 0)
            value = value[..suffix];
        return value.Trim('/').ToLowerInvariant();
    }

    public static TarazinModule? Match(string relativePath)
    {
        var path = NormalizeRelativePath(relativePath);
        if (string.IsNullOrEmpty(path) || path is "login" or "diag")
            return null;
        var key = path.Split('/', 2)[0];
        return All.FirstOrDefault(m => m.Key == key);
    }

    /// <summary>
    /// دسترسی لازم برای یک مسیر نسبی. مسیرهای عمومی (خانه/ورود/عیب‌یابی)
    /// null برمی‌گردانند. برای مسیرهای ناشناخته null (بدون محافظت).
    /// </summary>
    public static string? RequiredPermissionFor(string relativePath)
    {
        var path = "/" + NormalizeRelativePath(relativePath);
        if (path is "/" or "/login" or "/diag")
            return null;

        TarazinNavItem? best = null;
        var bestLen = -1;
        foreach (var m in All)
        {
            foreach (var item in m.Items)
            {
                var url = "/" + item.Url.Trim().Trim('/').ToLowerInvariant();
                if (path == url || path.StartsWith(url + "/", StringComparison.OrdinalIgnoreCase))
                {
                    if (url.Length > bestLen)
                    {
                        best = item;
                        bestLen = url.Length;
                    }
                }
            }
        }

        return best?.Permission;
    }

    public static bool IsActive(string currentPath, string href)
    {
        var cur = "/" + NormalizeRelativePath(currentPath);
        var target = "/" + (href ?? "").Trim().Trim('/').ToLowerInvariant();
        if (cur == "/") return target == "/";
        if (target == "/") return cur == "/";
        if (cur == target) return true;
        // Root of a module must not stay active on child pages.
        var isModuleRoot = All.Any(m => string.Equals(m.Url, target, StringComparison.OrdinalIgnoreCase));
        return !isModuleRoot && cur.StartsWith(target + "/", StringComparison.OrdinalIgnoreCase);
    }
}
