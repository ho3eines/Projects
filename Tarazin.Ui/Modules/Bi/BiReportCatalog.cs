namespace Tarazin.Services;

/// <summary>
/// کاتالوگ مشترک گزارش‌های BI — منبع واحد برای صفحهٔ گزارش‌ها (`/bi/reports`)
/// و صفحهٔ تست توسعه (`/dev/bireport`). هر گزارش یک <see cref="BiReportDefinition"/>
/// است: اسکریپت نامدار + پارامترها + عنوان فارسی ستون‌ها.
/// </summary>
public static class BiReportCatalog
{
    public static readonly IReadOnlyList<BiReportDefinition> Reports = new List<BiReportDefinition>
    {
        new("wallet", "کیف پول و موجودی ارز", "هر ارز با واحد اصلی، ارزش ریالی و سود/زیان", "currency", "WalletList",
            new() { ["FromDate"] = null, ["ToDate"] = null, ["OnlyNonZero"] = 0 },
            Titles("CurrencyCode","ارز","CurrencyName","نام","Quantity","موجودی","AvgBuyRate","متوسط خرید","SystemRate","نرخ سیستم","RialValue","ارزش ریالی","UnrealizedPnl","سود/زیان")),
        new("fx", "گزارش معاملات ارز", "خرید/فروش/تبدیل/ترکیبی", "currency", "FxTransactionList",
            new() { ["FromDate"] = null, ["ToDate"] = null, ["TransactionType"] = null, ["SearchText"] = "", ["SkipRows"] = 0, ["TakeSize"] = 500 },
            Titles("TransactionNumber","شماره","TransactionDate","تاریخ","TransactionType","نوع","PartyName","طرف حساب","TotalRial","مبلغ ریالی","DocumentNumber","سند","Status","وضعیت")),
        new("asset", "ارزش لحظه‌ای دارایی", "ارزش هر دارایی به ریال بر اساس نرخ سیستم", "currency", "AssetValuation",
            new(),
            Titles("GroupKey","گروه","Title","دارایی","Unit","واحد","Quantity","مقدار","Rate","نرخ","RialValue","ارزش ریالی")),
        new("rates", "مرکز نرخ‌ها و قیمت‌ها", "انواع نرخ هر آیتم (آنلاین/سیستم/خرید/فروش)", "currency", "RateBoard",
            new() { ["ItemType"] = null, ["ItemKey"] = null },
            Titles("ItemType","نوع","ItemKey","کلید","Title","عنوان","OnlineRate","آنلاین","SystemRate","سیستم","BuyRate","خرید","SellRate","فروش","SourceTitle","منبع","Status","وضعیت")),
        new("pnl", "سود و زیان (طلا + ارز)", "تفکیک سود محقق‌شده و محقق‌نشده", "currency", "PnlSummary",
            new() { ["FromDate"] = null, ["ToDate"] = null },
            Titles("Title","عنوان","Amount","مبلغ (ریال)")),
        new("trial", "تراز آزمایشی", "ماندهٔ همهٔ حساب‌ها در بازه", "accounting", "TrialBalanceReport",
            new() { ["FromDate"] = null, ["ToDate"] = null },
            Titles("AccountCode","کد","AccountTitle","حساب","AccountType","نوع","Debit","بدهکار","Credit","بستانکار","Balance","مانده")),
        new("cashflow", "گردش نقدی", "دریافت‌ها و پرداخت‌ها در بازه", "treasury", "CashFlowReport",
            new() { ["FromDate"] = null, ["ToDate"] = null },
            Titles("MovementDate","تاریخ","MovementNumber","شماره","Direction","جهت","Amount","مبلغ","CurrencyCode","ارز","AccountName","حساب","Description","شرح")),
        new("gold", "فروش روزانه طلا", "فاکتورهای طلافروشی", "goldshop", "DailySales",
            new(),
            Titles("InvoiceNumber","شماره","InvoiceDate","تاریخ","CustomerName","مشتری","ItemCode","کد جنس","ItemTitle","جنس","WeightGram","وزن","Workmanship","اجرت","Profit","سود","Tax","مالیات","TotalAmount","مبلغ کل")),
        new("alerts", "هشدارهای سیستم", "ریسک‌ها و هشدارهای فعال از دادهٔ واقعی", "bi", "BiAlerts",
            new(),
            Titles("Severity","شدت","Title","عنوان","Detail","جزئیات","Amount","مبلغ","OccurredAt","زمان","Source","منبع","Action","اقدام")),
        new("review", "گزارش جامع دوره (Monthly/Yearly Review)", "فروش/سود/هزینه/نقدینگی/طلا/ارز/موجودی/مطالبات/بدهی/چک — مقایسه با فیلتر سراسری (§113/§114)", "bi", "BiReviewSummary",
            new() { ["FromDate"] = null, ["ToDate"] = null },
            Titles("Title","عنوان","Amount","مبلغ (ریال)")),
        new("ratios", "نسبت‌های مالی", "حاشیه سود، DSO، نسبت‌های نقدینگی و بدهی (§94)", "bi", "BiFinancialRatios",
            new(),
            Titles("Title","عنوان","Amount","مقدار","Unit","واحد","Formula","فرمول","Source","منبع")),
        new("payablesaging", "Aging بدهی‌ها", "سن اسناد خرید (§22)", "bi", "BiPayablesAging",
            new(),
            Titles("Title","بازه","Value","مبلغ","SecondaryValue","درصد")),
        new("income", "ترکیب درآمد", "سهم کانال‌های درآمد (§10)", "bi", "BiIncomeComposition",
            new(),
            Titles("Title","کانال","Value","مبلغ","SecondaryValue","درصد")),
        new("tax", "گزارش مالیات", "مالیات وصولی فاکتورهای طلا (§89)", "bi", "BiTaxKpis",
            new(),
            Titles("Title","عنوان","Amount","مقدار","Unit","واحد")),
        new("purchase", "گزارش خرید", "خرید و تأمین‌کنندگان (§31–§33)", "bi", "BiPurchaseKpis",
            new(),
            Titles("Title","عنوان","Amount","مقدار","Unit","واحد")),
        new("expense", "گزارش هزینه‌ها", "هزینه به تفکیک حساب (§68–§70)", "bi", "BiExpenseComposition",
            new() { ["FromDate"] = null, ["ToDate"] = null },
            Titles("Title","عنوان","Value","مبلغ","SecondaryValue","درصد")),
        new("assets", "اموال و دارایی ثابت", "ارزش/استهلاک/ارزش دفتری (§73)", "bi", "BiAssetKpis",
            new(),
            Titles("Title","عنوان","Amount","مقدار","Unit","واحد")),
        new("branches", "شعب", "فروش هر شعبه (§86)", "bi", "BiBranchKpis",
            new(),
            Titles("Col1","شعبه","Col2","فروش طلا","Col3","فروش فروشگاه","Col4","توضیح","Amount","مجموع")),
    };

    /// <summary>ساخت نگاشت نام ستون ← عنوان فارسی (جفت‌های متوالی).</summary>
    public static IReadOnlyDictionary<string, string> Titles(params string[] pairs)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < pairs.Length; i += 2)
            map[pairs[i]] = pairs[i + 1];
        return map;
    }
}
