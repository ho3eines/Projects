using System.Text.Json;
using System.Text.Json.Serialization;
using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// مدیریت قالب‌های چاپ (موتور چاپ عمومی) — خواندن/ذخیره در دیتابیس
/// (<c>printing.PrintTemplates</c>) + قالب‌های پیش‌فرض داخلی برای هر گزارش.
///
/// الگوی استفاده:
/// <code>
///   var tpl = await Tpl.GetAsync("treasury.cheques") ?? PrintTemplates.Defaults.Get("treasury.cheques");
///   var data = new PrintDataModel { Title = ..., Rows = rows, MetaFields = ... };
///   // نمایش دیالوگ چاپ (TemplatePrintDialog) با همین tpl + data
/// </code>
/// قالب در حالت دیزاین (صفحهٔ /central/printing) ذخیره می‌شود و از آن پس
/// برای همان گزارش استفاده می‌شود — «هر گزارش قالب مجزای خودش را دارد».
/// </summary>
public sealed class PrintTemplateService
{
    private const string Schema = "printing";

    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly DbService _db;
    private readonly UserSession _session;

    public PrintTemplateService(DbService db, UserSession session)
    {
        _db = db;
        _session = session;
    }

    /// <summary>فهرست قالب‌ها (اختیاری: فیلتر ماژول).</summary>
    public Task<IReadOnlyList<PrintTemplateRow>> ListAsync(string? module = null)
        => _db.QueryAsync<PrintTemplateRow>(Schema, "PrintTemplateList", new { Module = module });

    /// <summary>بارگذاری یک قالب (با ستون‌ها و فیلدهای هدر). اگر نبود null.</summary>
    public async Task<PrintTemplateDef?> GetAsync(string id)
    {
        var row = await _db.QueryFirstOrDefaultAsync<PrintTemplateRow>(Schema, "PrintTemplateGet", new { Id = id });
        return row is null ? null : FromRow(row);
    }

    /// <summary>
    /// قالب مورداستفادهٔ یک گزارش برای شرکتِ جاری نشست، به این ترتیب:
    /// ۱) قالب ذخیره‌شده با همان شناسهٔ گزارش (پوشش مستقیم)،
    /// ۲) قالبِ «پیش‌فرض» همان گزارش — اول قالبِ همین شرکت، بعد قالبِ سراسری
    ///    (DefaultFor، بدون تغییر کد)،
    /// ۳) قالب پیش‌فرض داخلی.
    /// </summary>
    public async Task<PrintTemplateDef> GetOrCreateDefaultAsync(string id)
    {
        var direct = await GetAsync(id);
        if (direct is not null) return direct;
        var byDefault = await GetByDefaultForAsync(id);
        if (byDefault is not null) return byDefault;
        return PrintTemplates.Defaults.Get(id);
    }

    /// <summary>
    /// قالب سفارشی که برای این گزارش «پیش‌فرض» شده در شرکتِ جاری (DefaultFor)
    /// یا null. اولویت: قالبِ همین شرکت → قالبِ سراسری (CompanyId NULL).
    /// </summary>
    public async Task<PrintTemplateDef?> GetByDefaultForAsync(string reportId)
    {
        var row = await _db.QueryFirstOrDefaultAsync<PrintTemplateRow>(Schema, "PrintTemplateGetByDefaultFor", new
        {
            ReportId = reportId,
            CompanyId = _session.ActiveCompanyId
        });
        return row is null ? null : FromRow(row);
    }

    /// <summary>یک قالب را «پیش‌فرض»ِ گزارشِ شرکتِ جاری کن (سایر پیش‌فرض‌های همان شرکت آزاد می‌شود).</summary>
    public Task SetDefaultForAsync(string templateId, string reportId)
        => _db.ExecuteAsync(Schema, "PrintTemplateSetDefaultFor", new
        {
            TemplateId = templateId,
            ReportId = reportId,
            CompanyId = _session.ActiveCompanyId,
            UpdatedBy = _session.UserName
        });

    /// <summary>برداشتن «پیش‌فرض بودن» یک قالب (قالب دوباره مشترک/سراسری می‌شود).</summary>
    public Task ClearDefaultForAsync(string templateId)
        => _db.ExecuteAsync(Schema, "PrintTemplateClearDefaultFor", new { Id = templateId, UpdatedBy = _session.UserName });

    /// <summary>ذخیره (درج/به‌روزرسانی) یک قالب از حالت دیزاین.</summary>
    public Task SaveAsync(PrintTemplateDef tpl)
        => _db.ExecuteAsync(Schema, "PrintTemplateUpsert", new
        {
            Id = tpl.Id,
            Name = tpl.Name,
            Description = tpl.Description,
            Module = tpl.Module,
            PaperSize = tpl.PaperSize.ToString(),
            Orientation = tpl.Orientation.ToString(),
            MarginMm = tpl.MarginMm,
            FontSizePt = tpl.FontSizePt,
            ShowCompanyHeader = tpl.ShowCompanyHeader,
            ShowPageFooter = tpl.ShowPageFooter,
            ShowReportFooter = tpl.ShowReportFooter,
            QrEnabled = tpl.QrEnabled,
            ReportTitle = tpl.ReportTitle,
            ReportSubtitle = tpl.ReportSubtitle,
            ColumnsJson = JsonSerializer.Serialize(tpl.Columns, Json),
            MetaJson = JsonSerializer.Serialize(tpl.MetaFields, Json),
            IsSystem = tpl.IsSystem,
            DefaultFor = tpl.DefaultFor,
            // «پیش‌فرض بودن» همیشه به دامنهٔ شرکتِ جاری محدود می‌شود (کلید یکتای (CompanyId, DefaultFor))
            CompanyId = string.IsNullOrWhiteSpace(tpl.DefaultFor) ? (int?)null : _session.ActiveCompanyId,
            UpdatedBy = _session.UserName
        });

    /// <summary>حذف قالب غیرسیستمی.</summary>
    public Task DeleteAsync(string id)
        => _db.ExecuteAsync(Schema, "PrintTemplateDelete", new { Id = id });

    /// <summary>
    /// «بازنشانی به قالب پیش‌فرض داخلی» — ردیف ذخیره‌شدهٔ قالب حذف می‌شود
    /// (و با آن DefaultFor پاک می‌شود) تا گزارش دوباره از تعریف داخلیِ کد استفاده کند.
    /// </summary>
    public Task ResetToDefaultAsync(string templateId)
        => _db.ExecuteAsync(Schema, "PrintTemplateReset", new { Id = templateId });

    private static PrintTemplateDef FromRow(PrintTemplateRow row)
    {
        var tpl = new PrintTemplateDef
        {
            Id = row.Id,
            Name = row.Name,
            Description = row.Description,
            Module = row.Module ?? "",
            PaperSize = ParseEnum(row.PaperSize, PrintPaperSize.A4),
            Orientation = ParseEnum(row.Orientation, PrintOrientation.Portrait),
            MarginMm = row.MarginMm,
            FontSizePt = row.FontSizePt,
            ShowCompanyHeader = row.ShowCompanyHeader,
            ShowPageFooter = row.ShowPageFooter,
            ShowReportFooter = row.ShowReportFooter,
            QrEnabled = row.QrEnabled,
            ReportTitle = row.ReportTitle,
            ReportSubtitle = row.ReportSubtitle,
            IsSystem = row.IsSystem,
            DefaultFor = row.DefaultFor,
            CompanyId = row.CompanyId,
            UpdatedAt = row.UpdatedAt,
            UpdatedBy = row.UpdatedBy
        };

        if (!string.IsNullOrWhiteSpace(row.ColumnsJson))
        {
            try { tpl.Columns = JsonSerializer.Deserialize<List<PrintColumnDef>>(row.ColumnsJson, Json) ?? new(); }
            catch { tpl.Columns = new(); }
        }
        if (!string.IsNullOrWhiteSpace(row.MetaJson))
        {
            try { tpl.MetaFields = JsonSerializer.Deserialize<List<PrintMetaField>>(row.MetaJson, Json) ?? new(); }
            catch { tpl.MetaFields = new(); }
        }
        return tpl;
    }

    private static T ParseEnum<T>(string? value, T fallback) where T : struct
        => Enum.TryParse<T>(value, true, out var v) ? v : fallback;
}

/// <summary>قالب‌های پیش‌فرض داخلی — برای گزارش‌هایی که هنوز قالب ذخیره‌شده ندارند.</summary>
public static class PrintTemplates
{
    public static class Defaults
    {
        /// <summary>شناسهٔ قالب‌های پیش‌فرض شناخته‌شده (برای فهرست مدیریت چاپ).</summary>
        public static readonly IReadOnlyList<string> Known =
            new[]
            {
                "treasury.cheques", "accounting.document", "accounting.documents",
                "inventory.balances", "inventory.card",
                "payroll.runs", "payroll.slips",
                "goldshop.sales", "goldshop.prices",
                "store.orders"
            };

        /// <summary>قالب پیش‌فرض برای شناسهٔ ناشناخته — با یک ستون «توضیح».</summary>
        public static PrintTemplateDef Get(string id)
        {
            if (id == "treasury.cheques") return Cheques();
            if (id == "accounting.document") return AccountingDocument();
            if (id == "accounting.documents") return AccountingDocuments();
            if (id == "inventory.balances") return InventoryBalances();
            if (id == "inventory.card") return InventoryCard();
            if (id == "payroll.runs") return PayrollRuns();
            if (id == "payroll.slips") return PayrollSlips();
            if (id == "goldshop.sales") return GoldShopSales();
            if (id == "goldshop.prices") return GoldShopPrices();
            if (id == "store.orders") return StoreOrders();
            return Generic(id);
        }

        private static PrintTemplateDef Generic(string id) => new()
        {
            Id = id,
            Name = $"قالب پیش‌فرض — {id}",
            Description = "قالب عمومی (بدون ستون تعریف‌شده). در صفحهٔ مدیریت چاپ شخصی‌سازی کنید.",
            Module = id.Split('.')[0],
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            MarginMm = 12,
            FontSizePt = 9,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = false,
            QrEnabled = false,
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "Description", Title = "شرح", Width = 100, Align = PrintAlign.Start }
            }
        };

        /// <summary>قالب گزارش چک‌های خزانه‌داری (A4 landscape).</summary>
        private static PrintTemplateDef Cheques() => new()
        {
            Id = "treasury.cheques",
            Name = "گزارش چک‌ها — خزانه‌داری",
            Description = "چک‌های در جریان/وصول/برگشتی به تفکیک وضعیت و سررسید.",
            Module = "treasury",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "گزارش چک‌ها",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "وضعیت", Bold = false },
                new() { Label = "شرکت", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "ChequeNumber", Title = "شماره چک", Width = 90, Bold = true },
                new() { Key = "BankName", Title = "بانک", Width = 90 },
                new() { Key = "Direction", Title = "جهت", Width = 70, Align = PrintAlign.Center },
                new() { Key = "StatusTitle", Title = "وضعیت", Width = 90, Align = PrintAlign.Center },
                new() { Key = "DueDate", Title = "سررسید", Width = 85, Align = PrintAlign.Center },
                new() { Key = "AlertTitle", Title = "هشدار", Width = 90, Align = PrintAlign.Center },
                new() { Key = "Amount", Title = "مبلغ", Width = 110, Align = PrintAlign.End, Format = "N0", Total = true },
                new() { Key = "SourceReference", Title = "منبع", Width = 130 }
            }
        };

        /// <summary>قالب سند حسابداری (A4 پرتره).</summary>
        private static PrintTemplateDef AccountingDocument() => new()
        {
            Id = "accounting.document",
            Name = "سند حسابداری",
            Description = "چاپ سند حسابداری با ریز ردیف‌ها و جمع‌ها.",
            Module = "accounting",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            MarginMm = 10,
            FontSizePt = 9,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = true,
            ReportTitle = "سند حسابداری",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "شماره سند", Bold = true },
                new() { Label = "تاریخ", Bold = true },
                new() { Label = "نوع", Bold = false },
                new() { Label = "وضعیت", Bold = false },
                new() { Label = "طرف حساب", Bold = false },
                new() { Label = "مبلغ کل", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "AccountCode", Title = "کد", Width = 70, Bold = true },
                new() { Key = "Title", Title = "عنوان / شرح", Width = 200 },
                new() { Key = "Debit", Title = "بدهکار", Width = 100, Align = PrintAlign.End, Format = "N0", Total = true },
                new() { Key = "Credit", Title = "بستانکار", Width = 100, Align = PrintAlign.End, Format = "N0", Total = true }
            }
        };

        /// <summary>قالب فهرست اسناد حسابداری.</summary>
        private static PrintTemplateDef AccountingDocuments() => new()
        {
            Id = "accounting.documents",
            Name = "فهرست اسناد حسابداری",
            Description = "لیست اسناد در یک بازه.",
            Module = "accounting",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "فهرست اسناد",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "تعداد اسناد", Bold = true },
                new() { Label = "جمع کل", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "DocumentNumber", Title = "شماره", Width = 70, Bold = true },
                new() { Key = "DocumentDate", Title = "تاریخ", Width = 85, Align = PrintAlign.Center },
                new() { Key = "DocumentType", Title = "نوع", Width = 90 },
                new() { Key = "CounterPartyName", Title = "طرف حساب", Width = 150 },
                new() { Key = "StatusTitle", Title = "وضعیت", Width = 90, Align = PrintAlign.Center },
                new() { Key = "TotalAmount", Title = "مبلغ", Width = 110, Align = PrintAlign.End, Format = "N0", Total = true }
            }
        };

        /// <summary>قالب موجودی کالا — انبار.</summary>
        private static PrintTemplateDef InventoryBalances() => new()
        {
            Id = "inventory.balances",
            Name = "موجودی کالا — انبار",
            Description = "موجودی به تفکیک انبار/انبارک با قیمت و ارزش.",
            Module = "inventory",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "موجودی کالا",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "انبار", Bold = true },
                new() { Label = "تاریخ تهیه", Bold = false },
                new() { Label = "تعداد اقلام", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "ItemCode", Title = "کد", Width = 70, Bold = true },
                new() { Key = "ItemTitle", Title = "کالا", Width = 180 },
                new() { Key = "Unit", Title = "واحد", Width = 60, Align = PrintAlign.Center },
                new() { Key = "WarehouseName", Title = "انبار", Width = 100 },
                new() { Key = "SubWarehouseName", Title = "انبارک", Width = 100 },
                new() { Key = "StockQty", Title = "موجودی", Width = 80, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "UnitPrice", Title = "قیمت", Width = 90, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "StockValue", Title = "ارزش", Width = 100, Align = PrintAlign.End, Format = "N0", Total = true }
            }
        };

        /// <summary>قالب کاردکس کالا — انبار.</summary>
        private static PrintTemplateDef InventoryCard() => new()
        {
            Id = "inventory.card",
            Name = "کاردکس کالا — انبار",
            Description = "گردش دریافت/صدور و ماندهٔ جاری هر کالا.",
            Module = "inventory",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "کاردکس کالا",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "کالا", Bold = true },
                new() { Label = "بازه", Bold = false },
                new() { Label = "ماندهٔ ابتدا", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "MovementDate", Title = "تاریخ", Width = 80, Align = PrintAlign.Center },
                new() { Key = "MovementNumber", Title = "شماره", Width = 80, Bold = true },
                new() { Key = "MovementType", Title = "نوع", Width = 70, Align = PrintAlign.Center },
                new() { Key = "InQty", Title = "دریافت", Width = 70, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "OutQty", Title = "صدور", Width = 70, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "CostPrice", Title = "قیمت", Width = 90, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "BalanceQty", Title = "مانده تعداد", Width = 80, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "BalanceValue", Title = "مانده ارزش", Width = 100, Align = PrintAlign.End, Format = "N0", Total = true },
                new() { Key = "Description", Title = "شرح", Width = 150 }
            }
        };

        /// <summary>قالب دوره‌های حقوق — حقوق و دستمزد.</summary>
        private static PrintTemplateDef PayrollRuns() => new()
        {
            Id = "payroll.runs",
            Name = "دوره‌های حقوق — حقوق و دستمزد",
            Description = "دوره‌های حقوق و خالص پرداختی هر دوره.",
            Module = "payroll",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            MarginMm = 10,
            FontSizePt = 9,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "دوره‌های حقوق",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "تاریخ تهیه", Bold = false },
                new() { Label = "تعداد دوره‌ها", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "Period", Title = "دوره", Width = 120, Bold = true },
                new() { Key = "EmployeeCount", Title = "تعداد کارمند", Width = 100, Align = PrintAlign.Center },
                new() { Key = "NetTotal", Title = "خالص کل", Width = 110, Align = PrintAlign.End, Format = "N0", Total = true },
                new() { Key = "StatusTitle", Title = "وضعیت", Width = 90, Align = PrintAlign.Center },
                new() { Key = "CreatedAt", Title = "تاریخ", Width = 85, Align = PrintAlign.Center }
            }
        };

        /// <summary>قالب فیش حقوق دوره — حقوق و دستمزد.</summary>
        private static PrintTemplateDef PayrollSlips() => new()
        {
            Id = "payroll.slips",
            Name = "فیش حقوق دوره — حقوق و دستمزد",
            Description = "خالص پرداختی هر کارمند در دورهٔ انتخاب‌شده.",
            Module = "payroll",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            MarginMm = 10,
            FontSizePt = 9,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "فیش حقوق دوره",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "دوره", Bold = true },
                new() { Label = "تعداد فیش", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "EmployeeId", Title = "کد کارمند", Width = 90, Align = PrintAlign.Center },
                new() { Key = "EmployeeName", Title = "نام", Width = 180, Bold = true },
                new() { Key = "NetPay", Title = "خالص پرداخت", Width = 110, Align = PrintAlign.End, Format = "N0", Total = true }
            }
        };

        /// <summary>قالب فروش روز — طلافروشی.</summary>
        private static PrintTemplateDef GoldShopSales() => new()
        {
            Id = "goldshop.sales",
            Name = "فروش روز — طلافروشی",
            Description = "فاکتورهای فروش طلا و جواهرات در بازهٔ تاریخ.",
            Module = "goldshop",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "فروش روز طلا",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "تعداد فاکتور", Bold = true },
                new() { Label = "جمع فروش", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "InvoiceNumber", Title = "شماره", Width = 80, Bold = true },
                new() { Key = "InvoiceDate", Title = "تاریخ", Width = 80, Align = PrintAlign.Center },
                new() { Key = "CustomerName", Title = "مشتری", Width = 140 },
                new() { Key = "ItemCode", Title = "کد جنس", Width = 70 },
                new() { Key = "ItemTitle", Title = "کالا", Width = 120 },
                new() { Key = "WeightGram", Title = "وزن (گرم)", Width = 80, Align = PrintAlign.End, Format = "N3" },
                new() { Key = "Workmanship", Title = "اجرت", Width = 80, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "Profit", Title = "سود", Width = 80, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "Tax", Title = "مالیات", Width = 80, Align = PrintAlign.End, Format = "N0" },
                new() { Key = "TotalAmount", Title = "جمع", Width = 100, Align = PrintAlign.End, Format = "N0", Total = true }
            }
        };

        /// <summary>قالب تاریخچه قیمت طلا — طلافروشی.</summary>
        private static PrintTemplateDef GoldShopPrices() => new()
        {
            Id = "goldshop.prices",
            Name = "تاریخچه قیمت طلا — طلافروشی",
            Description = "قیمت هر گرم اقلام طلا و جواهرات.",
            Module = "goldshop",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            MarginMm = 10,
            FontSizePt = 9,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = false,
            QrEnabled = false,
            ReportTitle = "تاریخچه قیمت طلا",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "تاریخ تهیه", Bold = false },
                new() { Label = "تعداد اقلام", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "ItemCode", Title = "کد", Width = 90, Bold = true },
                new() { Key = "Title", Title = "عنوان", Width = 180 },
                new() { Key = "PricePerGram", Title = "قیمت هر گرم", Width = 120, Align = PrintAlign.End, Format = "N0", Total = false },
                new() { Key = "UpdatedAt", Title = "به‌روزرسانی", Width = 110, Align = PrintAlign.Center }
            }
        };

        /// <summary>قالب گزارش سفارش‌ها — فروشگاه.</summary>
        private static PrintTemplateDef StoreOrders() => new()
        {
            Id = "store.orders",
            Name = "گزارش سفارش‌ها — فروشگاه",
            Description = "سفارش‌ها بر اساس وضعیت در بازهٔ تاریخ.",
            Module = "store",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            QrEnabled = false,
            ReportTitle = "گزارش سفارش‌ها",
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "تعداد سفارش", Bold = true },
                new() { Label = "جمع مبلغ", Bold = true }
            },
            Columns = new List<PrintColumnDef>
            {
                new() { Key = "OrderNumber", Title = "شماره", Width = 90, Bold = true },
                new() { Key = "OrderDate", Title = "تاریخ", Width = 85, Align = PrintAlign.Center },
                new() { Key = "CustomerName", Title = "مشتری", Width = 140 },
                new() { Key = "ItemCount", Title = "تعداد اقلام", Width = 80, Align = PrintAlign.Center },
                new() { Key = "TotalAmount", Title = "مبلغ", Width = 110, Align = PrintAlign.End, Format = "N0", Total = true },
                new() { Key = "StatusTitle", Title = "وضعیت", Width = 90, Align = PrintAlign.Center }
            }
        };
    }
}
