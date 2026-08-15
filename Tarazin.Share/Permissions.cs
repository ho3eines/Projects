namespace Tarazin.Models;

// ============================================================
// Access control catalog (RBAC).
// Single source of truth for permission keys + default roles.
// At startup TarazinDbInitializer syncs this catalog into
// [central].[Permissions] / [central].[Roles] (idempotent).
// ============================================================

/// <summary>یک دسترسی (Permission) قابل اعطا به نقش‌ها.</summary>
public sealed record PermissionDef(string Key, string Title, string ModuleKey);

/// <summary>اقدامات استاندارد هر ماژول.</summary>
public static class TarazinActions
{
    public const string View = "view";
    public const string Entry = "entry";
    public const string Special = "special";
    public const string Reports = "reports";
    public const string Settings = "settings";
    public const string Admin = "admin";
}

/// <summary>فهرست کامل دسترسی‌ها با الگوی <c>{module}.{action}</c>.</summary>
public static class TarazinPermissions
{
    // دسترسی‌های سیستمی (خارج از ماژول‌ها).
    public const string Users = "system.users";
    public const string Roles = "system.roles";
    public const string Audit = "system.audit";
    public const string SystemAdmin = "system.admin";

    // ── دسترسی‌های ویژهٔ نرخ‌ها و قیمت‌ها (PRD §55) ─────────────────────
    // نرخ‌ها قلب قیمت‌گذاری سیستم‌اند؛ تغییر/Override فقط برای کاربران مجاز.
    public const string RateView = "rates.view";              // مشاهده نرخ
    public const string RateFetch = "rates.fetch";            // دریافت نرخ (آنلاین/دستی)
    public const string RateChange = "rates.change";          // تغییر نرخ (سیستم)
    public const string RateOverride = "rates.override";      // Override نرخ آنلاین ← سیستم
    public const string RateChangeBuy = "rates.buy";          // تغییر نرخ خرید
    public const string RateChangeSell = "rates.sell";        // تغییر نرخ فروش
    public const string RateChangeGold = "rates.gold";        // تغییر نرخ طلا
    public const string RateChangeCurrency = "rates.currency";// تغییر نرخ ارز
    public const string RateHistory = "rates.history";        // مشاهدهٔ تاریخچه نرخ
    public const string RateConfirm = "rates.confirm";        // تأیید نرخ

    // ── دسترسی‌های ماژول «جداول پایه» (حسابداری) ─────────────────────────
    // 9 دسترسی مطابق PRD: مشاهده/ایجاد/ویرایش/حذف حساب، انتقال، جابه‌جایی،
    // مدیریت تفصیلی، انتخاب حساب، مشاهده ساختار کامل.
    public const string ChartView = "accounting.chart.view";         // مشاهده جداول پایه
    public const string ChartCreate = "accounting.chart.create";     // ایجاد حساب
    public const string ChartEdit = "accounting.chart.edit";         // ویرایش حساب
    public const string ChartDelete = "accounting.chart.delete";     // حذف حساب
    public const string ChartMove = "accounting.chart.move";         // انتقال حساب
    public const string ChartReorder = "accounting.chart.reorder";   // جابه‌جایی درخت
    public const string ChartManageDetil = "accounting.chart.detil"; // مدیریت حساب‌های تفصیلی
    public const string ChartSelect = "accounting.chart.select";     // انتخاب حساب
    public const string ChartFullTree = "accounting.chart.fulltree"; // مشاهده ساختار کامل حساب‌ها

    // ── دسترسی‌های «سند حسابداری» ────────────────────────────────────────
    // ویرایش/حذف سند و تغییر وضعیت آن (یادداشت → موقت → تأیید شده → تأیید نهایی).
    // توجه: داشتن دسترسی به‌تنهایی کافی نیست؛ وضعیت فعلی سند هم شرط است
    // (ویرایش فقط در «یادداشت» و «سند موقت» مجاز است).
    public const string DocumentEdit = "accounting.document.edit";         // ویرایش سند
    public const string DocumentDelete = "accounting.document.delete";     // حذف سند
    public const string DocumentDraft = "accounting.document.draft";       // یادداشت → سند موقت
    public const string DocumentConfirm = "accounting.document.confirm";   // سند موقت → تأیید شده
    public const string DocumentFinalize = "accounting.document.finalize"; // تأیید شده → تأیید نهایی
    public const string DocumentRevert = "accounting.document.revert";     // برگشت وضعیت سند

    /// <summary>کلید ماژول‌های کسب‌وکار (همان اسکیمه‌ها).</summary>
    public static readonly string[] Modules =
    [
        "central", "accounting", "inventory", "treasury",
        "payroll", "goldshop", "store", "currency", "bi",
        "assets", "branch"
    ];

    /// <summary>اقدامات استاندارد هر ماژول.</summary>
    public static readonly string[] Actions =
    [
        TarazinActions.View, TarazinActions.Entry, TarazinActions.Special,
        TarazinActions.Reports, TarazinActions.Settings, TarazinActions.Admin
    ];

    private static readonly Dictionary<string, string> ActionTitles = new(StringComparer.OrdinalIgnoreCase)
    {
        [TarazinActions.View] = "مشاهده",
        [TarazinActions.Entry] = "ثبت عملیات",
        [TarazinActions.Special] = "عملیات ویژه",
        [TarazinActions.Reports] = "گزارش‌ها",
        [TarazinActions.Settings] = "تنظیمات و جداول پایه",
        [TarazinActions.Admin] = "مدیریت کامل",
    };

    private static readonly Dictionary<string, string> ModuleTitles = new(StringComparer.OrdinalIgnoreCase)
    {
        ["central"] = "پلتفرم مشترک",
        ["accounting"] = "حسابداری",
        ["inventory"] = "انبار",
        ["treasury"] = "خزانه‌داری",
        ["payroll"] = "حقوق و دستمزد",
        ["goldshop"] = "طلافروشی",
        ["store"] = "فروشگاه",
        ["currency"] = "ارز و معاملات ارزی",
        ["bi"] = "داشبورد و هوش تجاری",
        ["assets"] = "اموال و دارایی ثابت",
        ["branch"] = "شعب",
        ["rates"] = "نرخ‌ها و قیمت‌ها",
        ["system"] = "سیستم و مدیریت",
    };

    /// <summary>تمام دسترسی‌های سیستم (منبع واحد برای seed و UI).</summary>
    public static IReadOnlyList<PermissionDef> All { get; } = Build();

    /// <summary>ساخت کلید دسترسی: <c>accounting.view</c>.</summary>
    public static string For(string moduleKey, string action) => $"{moduleKey}.{action}";

    /// <summary>کلید «مشاهده» یک ماژول.</summary>
    public static string ViewKey(string moduleKey) => For(moduleKey, TarazinActions.View);

    public static string ModuleTitle(string moduleKey) =>
        ModuleTitles.TryGetValue(moduleKey, out var t) ? t : moduleKey;

    public static string ActionTitle(string action) =>
        ActionTitles.TryGetValue(action, out var t) ? t : action;

    private static IReadOnlyList<PermissionDef> Build()
    {
        var list = new List<PermissionDef>();

        foreach (var module in Modules)
            foreach (var action in Actions)
                list.Add(new PermissionDef(For(module, action),
                    $"{ModuleTitle(module)} — {ActionTitle(action)}", module));

        list.Add(new PermissionDef(Users, "مدیریت کاربران (ایجاد/ویرایش/حذف)", "system"));
        list.Add(new PermissionDef(Roles, "مدیریت نقش‌ها و دسترسی‌ها", "system"));
        list.Add(new PermissionDef(Audit, "مشاهدهٔ ممیزی سیستم", "system"));
        list.Add(new PermissionDef(SystemAdmin, "مدیریت کامل سیستم", "system"));

        // دسترسی‌های ویژهٔ نرخ‌ها و قیمت‌ها (PRD §55) — منبع واحد برای seed و UI.
        list.Add(new PermissionDef(RateView, "مشاهده نرخ", "rates"));
        list.Add(new PermissionDef(RateFetch, "دریافت نرخ (آنلاین/دستی)", "rates"));
        list.Add(new PermissionDef(RateChange, "تغییر نرخ سیستم", "rates"));
        list.Add(new PermissionDef(RateOverride, "Override نرخ آنلاین", "rates"));
        list.Add(new PermissionDef(RateChangeBuy, "تغییر نرخ خرید", "rates"));
        list.Add(new PermissionDef(RateChangeSell, "تغییر نرخ فروش", "rates"));
        list.Add(new PermissionDef(RateChangeGold, "تغییر نرخ طلا", "rates"));
        list.Add(new PermissionDef(RateChangeCurrency, "تغییر نرخ ارز", "rates"));
        list.Add(new PermissionDef(RateHistory, "مشاهده تاریخچه نرخ", "rates"));
        list.Add(new PermissionDef(RateConfirm, "تأیید نرخ", "rates"));

        // دسترسی‌های ماژول «جداول پایه» (PRD §جداول پایه)
        list.Add(new PermissionDef(ChartView, "حسابداری — مشاهده جداول پایه", "accounting"));
        list.Add(new PermissionDef(ChartCreate, "حسابداری — ایجاد حساب (کل/معین/تفصیلی)", "accounting"));
        list.Add(new PermissionDef(ChartEdit, "حسابداری — ویرایش حساب", "accounting"));
        list.Add(new PermissionDef(ChartDelete, "حسابداری — حذف حساب", "accounting"));
        list.Add(new PermissionDef(ChartMove, "حسابداری — انتقال حساب", "accounting"));
        list.Add(new PermissionDef(ChartReorder, "حسابداری — جابه‌جایی درخت", "accounting"));
        list.Add(new PermissionDef(ChartManageDetil, "حسابداری — مدیریت حساب‌های تفصیلی", "accounting"));
        list.Add(new PermissionDef(ChartSelect, "حسابداری — انتخاب حساب (Picker)", "accounting"));
        list.Add(new PermissionDef(ChartFullTree, "حسابداری — مشاهده ساختار کامل حساب‌ها", "accounting"));

        // دسترسی‌های «سند حسابداری» (ویرایش/حذف/تغییر وضعیت)
        list.Add(new PermissionDef(DocumentEdit, "حسابداری — ویرایش سند حسابداری", "accounting"));
        list.Add(new PermissionDef(DocumentDelete, "حسابداری — حذف سند حسابداری", "accounting"));
        list.Add(new PermissionDef(DocumentDraft, "حسابداری — تبدیل یادداشت به سند موقت", "accounting"));
        list.Add(new PermissionDef(DocumentConfirm, "حسابداری — تأیید سند موقت", "accounting"));
        list.Add(new PermissionDef(DocumentFinalize, "حسابداری — تأیید نهایی سند", "accounting"));
        list.Add(new PermissionDef(DocumentRevert, "حسابداری — برگشت وضعیت سند", "accounting"));

        return list;
    }
}

/// <summary>نقش پیش‌فرض: کلید، عنوان، توضیح و دسترسی‌ها.</summary>
public sealed record DefaultRole(
    string Key,
    string Title,
    string Description,
    bool IsSystem,
    IReadOnlyList<string> Permissions);

/// <summary>نقش‌های پیش‌فرض سیستم — در استارت‌آپ با دیتابیس همگام می‌شوند.</summary>
public static class TarazinRoles
{
    public const string Admin = "Admin";

    public static IReadOnlyList<DefaultRole> Defaults { get; } = Build();

    /// <summary>تمام دسترسی‌های یک ماژول (۶ اقدام).</summary>
    private static string[] Full(string module) =>
    [
        TarazinPermissions.For(module, TarazinActions.View),
        TarazinPermissions.For(module, TarazinActions.Entry),
        TarazinPermissions.For(module, TarazinActions.Special),
        TarazinPermissions.For(module, TarazinActions.Reports),
        TarazinPermissions.For(module, TarazinActions.Settings),
        TarazinPermissions.For(module, TarazinActions.Admin),
    ];

    /// <summary>تمام دسترسی‌های ماژول «جداول پایه» حسابداری (9 اقدام).</summary>
    private static string[] FullChart() =>
    [
        TarazinPermissions.ChartView,
        TarazinPermissions.ChartCreate,
        TarazinPermissions.ChartEdit,
        TarazinPermissions.ChartDelete,
        TarazinPermissions.ChartMove,
        TarazinPermissions.ChartReorder,
        TarazinPermissions.ChartManageDetil,
        TarazinPermissions.ChartSelect,
        TarazinPermissions.ChartFullTree,
    ];

    /// <summary>تمام دسترسی‌های «سند حسابداری» (ویرایش/حذف/تغییر وضعیت).</summary>
    private static string[] FullDocument() =>
    [
        TarazinPermissions.DocumentEdit,
        TarazinPermissions.DocumentDelete,
        TarazinPermissions.DocumentDraft,
        TarazinPermissions.DocumentConfirm,
        TarazinPermissions.DocumentFinalize,
        TarazinPermissions.DocumentRevert,
    ];

    /// <summary>فقط مشاهده + گزارش برای همهٔ ماژول‌ها.</summary>
    private static string[] ViewReports()
    {
        var keys = new List<string>();
        foreach (var m in TarazinPermissions.Modules)
        {
            keys.Add(TarazinPermissions.For(m, TarazinActions.View));
            keys.Add(TarazinPermissions.For(m, TarazinActions.Reports));
        }
        return keys.ToArray();
    }

    private static IReadOnlyList<DefaultRole> Build()
    {
        string[] viewReports = ViewReports();

        return new List<DefaultRole>
        {
            new(Admin, "مدیر سیستم",
                "دسترسی کامل به تمام بخش‌ها، کاربران، نقش‌ها و ممیزی.", true,
                TarazinPermissions.All.Select(p => p.Key).ToList()),

            new("Accountant", "حسابدار",
                "حسابداری کامل + مشاهده و گزارش سایر بخش‌ها + ممیزی.", false,
                Full("accounting").Concat(FullChart()).Concat(FullDocument()).Concat(new[]
                {
                    TarazinPermissions.For("treasury", TarazinActions.View),
                    TarazinPermissions.For("treasury", TarazinActions.Reports),
                    TarazinPermissions.For("inventory", TarazinActions.View),
                    TarazinPermissions.For("inventory", TarazinActions.Reports),
                    TarazinPermissions.For("store", TarazinActions.View),
                    TarazinPermissions.For("store", TarazinActions.Reports),
                    TarazinPermissions.For("goldshop", TarazinActions.View),
                    TarazinPermissions.For("goldshop", TarazinActions.Reports),
                    TarazinPermissions.For("payroll", TarazinActions.View),
                    TarazinPermissions.For("payroll", TarazinActions.Reports),
                    TarazinPermissions.For("currency", TarazinActions.View),
                    TarazinPermissions.For("currency", TarazinActions.Reports),
                    TarazinPermissions.RateView,
                    TarazinPermissions.RateHistory,
                    TarazinPermissions.RateConfirm,
                    TarazinPermissions.For("central", TarazinActions.View),
                    TarazinPermissions.Audit,
                }).ToList()),

            new("Cashier", "صندوق‌دار",
                "خزانه‌داری کامل + فروش و طلافروشی + نرخ‌ها.", false,
                Full("treasury").Concat(new[]
                {
                    TarazinPermissions.For("goldshop", TarazinActions.View),
                    TarazinPermissions.For("goldshop", TarazinActions.Entry),
                    TarazinPermissions.For("store", TarazinActions.View),
                    TarazinPermissions.For("store", TarazinActions.Entry),
                    TarazinPermissions.For("currency", TarazinActions.View),
                    TarazinPermissions.For("currency", TarazinActions.Entry),
                    TarazinPermissions.For("currency", TarazinActions.Reports),
                    TarazinPermissions.RateView,
                    TarazinPermissions.RateFetch,
                    TarazinPermissions.RateChange,
                    TarazinPermissions.RateChangeBuy,
                    TarazinPermissions.RateChangeSell,
                    TarazinPermissions.RateChangeCurrency,
                    TarazinPermissions.RateHistory,
                    TarazinPermissions.For("central", TarazinActions.View),
                }).ToList()),

            new("Storekeeper", "انباردار",
                "انبار کامل + مشاهدهٔ حسابداری.", false,
                Full("inventory").Concat(new[]
                {
                    TarazinPermissions.For("accounting", TarazinActions.View),
                    TarazinPermissions.For("store", TarazinActions.View),
                    TarazinPermissions.For("central", TarazinActions.View),
                }).ToList()),

            new("Sales", "فروشنده",
                "فروشگاه کامل + ثبت فاکتور طلا + مشاهده نرخ.", false,
                Full("store").Concat(new[]
                {
                    TarazinPermissions.For("goldshop", TarazinActions.View),
                    TarazinPermissions.For("goldshop", TarazinActions.Entry),
                    TarazinPermissions.For("currency", TarazinActions.View),
                    TarazinPermissions.RateView,
                    TarazinPermissions.For("central", TarazinActions.View),
                }).ToList()),

            new("HR", "کارگزینی",
                "حقوق و دستمزد کامل + مشاهدهٔ خزانه.", false,
                Full("payroll").Concat(new[]
                {
                    TarazinPermissions.For("treasury", TarazinActions.View),
                    TarazinPermissions.For("central", TarazinActions.View),
                }).ToList()),

            new("Auditor", "حسابرس",
                "فقط مشاهده و گزارش تمام بخش‌ها + ممیزی.", false,
                viewReports.Concat(new[]
                {
                    TarazinPermissions.ChartView,
                    TarazinPermissions.ChartFullTree,
                    TarazinPermissions.RateView,
                    TarazinPermissions.RateHistory,
                    TarazinPermissions.Audit,
                }).ToList()),

            new("Viewer", "فقط مشاهده",
                "مشاهده و گزارش تمام بخش‌ها بدون ثبت عملیات.", false,
                viewReports.Concat(new[] { TarazinPermissions.RateView }).ToList()),

            // نقش پایهٔ پیش‌فرض — اسکریپت‌های fallback/backfill به آن ارجاع می‌دهند.
            // باید همیشه وجود داشته باشد تا هیچ کاربری بدون نقش/دسترسی نماند.
            new("User", "کاربر عادی",
                "دسترسی خواندن و مشاهدهٔ همهٔ بخش‌ها.", false,
                viewReports.ToList()),
        };
    }
}
