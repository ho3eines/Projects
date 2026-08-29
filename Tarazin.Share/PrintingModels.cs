using System.Text.Json.Serialization;

namespace Tarazin.Models;

/// <summary>اندازهٔ کاغذ قالب چاپ.</summary>
public enum PrintPaperSize
{
    A4,
    A5
}

/// <summary>جهت برگه.</summary>
public enum PrintOrientation
{
    Portrait,
    Landscape
}

/// <summary>تراز محتوا در یک سلول (در RTL: Start = راست، End = چپ).</summary>
public enum PrintAlign
{
    Start,
    Center,
    End
}

/// <summary>
/// تعریف یک ستون در جدول دیتیل قالب چاپ.
/// مقدار سلول از <c>PrintRow[Key]</c> خوانده می‌شود (تزریق مستقیم داده).
/// </summary>
public class PrintColumnDef
{
    public string Key { get; set; } = "";
    public string Title { get; set; } = "";
    /// <summary>عرض نسبی ستون (نسبت به جمع عرض‌ها).</summary>
    public int Width { get; set; } = 100;
    public PrintAlign Align { get; set; } = PrintAlign.Start;
    /// <summary>فرمت عددی (مثل "N0" یا "N3") — روی مقادیر عددی اعمال می‌شود.</summary>
    public string? Format { get; set; }
    public bool Bold { get; set; }
    /// <summary>آیا این ستون در فوتر گزارش (جمع‌ها) جمع شود؟</summary>
    public bool Total { get; set; }
    /// <summary>تورفتگی سلول بر اساس سطح سلسله‌مراتب (۰ = بدون تورفتگی).</summary>
    public int Indent { get; set; }
    /// <summary>رنگ پس‌زمینهٔ ردیف (اختیاری — برای ردیف‌های کل/معین).</summary>
    public string? RowBackground { get; set; }
}

/// <summary>یک فیلد «هدر داده» در قالب چاپ (برچسب + مقدار).</summary>
public class PrintMetaField
{
    public string Label { get; set; } = "";
    public string? Value { get; set; }
    public bool Bold { get; set; } = true;
}

/// <summary>
/// قالب چاپ یک گزارش — «باند»های استاندارد:
/// CompanyHeader (هدر اطلاعات شرکت)، ReportHeader (عنوان + هدر داده)،
/// ColumnHeader + Detail (لیست)، ReportFooter (جمع‌ها)، PageFooter (شماره صفحه).
/// با JSON در دیتابیس (printing.PrintTemplates) ذخیره می‌شود و در حالت
/// دیزاین (صفحهٔ /central/printing) قابل ویرایش است.
/// </summary>
public class PrintTemplateDef
{
    /// <summary>شناسهٔ یکتای قالب — معمولاً «ماژول.گزارش» مثل "treasury.cheques".</summary>
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    /// <summary>ماژول/اسکیمای مالک قالب (برای فیلتر در مدیریت چاپ).</summary>
    public string Module { get; set; } = "";
    public PrintPaperSize PaperSize { get; set; } = PrintPaperSize.A4;
    public PrintOrientation Orientation { get; set; } = PrintOrientation.Portrait;
    /// <summary>حاشیهٔ برگه به میلی‌متر.</summary>
    public int MarginMm { get; set; } = 12;
    public float FontSizePt { get; set; } = 9;
    public bool ShowCompanyHeader { get; set; } = true;
    public bool ShowPageFooter { get; set; } = true;
    public bool ShowReportFooter { get; set; } = true;
    public bool QrEnabled { get; set; } = true;
    /// <summary>عنوان پیش‌فرض گزارش (با Title لحظه‌ای داده جایگزین می‌شود).</summary>
    public string? ReportTitle { get; set; }
    /// <summary>زیرعنوان پیش‌فرض.</summary>
    public string? ReportSubtitle { get; set; }
    /// <summary>برچسب‌های هدر داده (مقادیر از PrintDataModel.MetaFields تزریق می‌شود).</summary>
    public List<PrintMetaField> MetaFields { get; set; } = new();
    /// <summary>ستون‌های جدول دیتیل.</summary>
    public List<PrintColumnDef> Columns { get; set; } = new();
    public bool IsSystem { get; set; }
    /// <summary>
    /// اگر پر باشد، این قالب «پیش‌فرض» آن گزارش است — یعنی وقتی مصرف‌کننده
    /// قالبِ <c>DefaultFor</c> را می‌خواهد، این قالب سفارشی به‌جای قالب داخلی
    /// (بدون تغییر کد) استفاده می‌شود. مقدار: شناسهٔ گزارش مثل "treasury.cheques".
    /// </summary>
    public string? DefaultFor { get; set; }
    /// <summary>
    /// دامنهٔ «پیش‌فرض بودن»: NULL = سراسری/مشترک (قالب‌های قدیمی)،
    /// غیر-NULL = فقط برای همان شرکت (هر شرکت پیش‌فرض چاپ جداگانه دارد؛
    /// کلید یکتا: (CompanyId, DefaultFor)).
    /// </summary>
    public int? CompanyId { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }

    public PrintTemplateDef Clone()
        => new()
        {
            Id = Id, Name = Name, Description = Description, Module = Module,
            PaperSize = PaperSize, Orientation = Orientation, MarginMm = MarginMm,
            FontSizePt = FontSizePt, ShowCompanyHeader = ShowCompanyHeader,
            ShowPageFooter = ShowPageFooter, ShowReportFooter = ShowReportFooter,
            QrEnabled = QrEnabled, ReportTitle = ReportTitle, ReportSubtitle = ReportSubtitle,
            MetaFields = MetaFields.Select(m => new PrintMetaField { Label = m.Label, Value = m.Value, Bold = m.Bold }).ToList(),
            Columns = Columns.Select(c => new PrintColumnDef
            {
                Key = c.Key, Title = c.Title, Width = c.Width, Align = c.Align,
                Format = c.Format, Bold = c.Bold, Total = c.Total, Indent = c.Indent,
                RowBackground = c.RowBackground
            }).ToList(),
            IsSystem = IsSystem,
            DefaultFor = DefaultFor,
            CompanyId = CompanyId
        };
}

/// <summary>ردیف دیتیل چاپ — نگاشت کلید ستون → مقدار (تزریق مستقیم داده).</summary>
public sealed class PrintRow : Dictionary<string, object?>
{
    public PrintRow() { }
    public PrintRow(IEnumerable<KeyValuePair<string, object?>> items) : base(items) { }
}

/// <summary>
/// دادهٔ یک چاپ — توسط صفحه/سرویس صدا زننده ساخته و «مستقیم» به موتور چاپ تزریق می‌شود.
/// </summary>
public class PrintDataModel
{
    public string CompanyName { get; set; } = "ترازین — سامانه یکپارچه مدیریت کسب‌وکار";
    public string? CompanyAddress { get; set; }
    public string? LogoPath { get; set; }
    /// <summary>عنوان لحظه‌ای گزارش (روی عنوان قالب اولویت دارد).</summary>
    public string Title { get; set; } = "";
    public string? Subtitle { get; set; }
    public string? RangeText { get; set; }
    /// <summary>مقادیر هدر داده — با برچسب‌های قالب جفت می‌شود (تزریق مستقیم).</summary>
    public List<PrintMetaField> MetaFields { get; set; } = new();
    /// <summary>ردیف‌های دیتیل.</summary>
    public List<PrintRow> Rows { get; set; } = new();
    /// <summary>فیلدهای فوتر گزارش (جمع‌ها/امضا) — تزریق مستقیم یا جمع خودکار ستون‌های Total.</summary>
    public List<PrintMetaField> FooterFields { get; set; } = new();
    public string? QrPayload { get; set; }
    public bool QrEnabled { get; set; } = true;
}

/// <summary>ردیف فهرست قالب‌ها (برای صفحهٔ مدیریت چاپ).</summary>
public class PrintTemplateRow
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public string Module { get; set; } = "";
    public string PaperSize { get; set; } = "A4";
    public string Orientation { get; set; } = "Portrait";
    public bool IsSystem { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
    public string? ColumnsJson { get; set; }
    public string? MetaJson { get; set; }
    public bool ShowCompanyHeader { get; set; } = true;
    public bool ShowPageFooter { get; set; } = true;
    public bool ShowReportFooter { get; set; } = true;
    public int MarginMm { get; set; } = 12;
    public float FontSizePt { get; set; } = 9;
    public string? ReportTitle { get; set; }
    public string? ReportSubtitle { get; set; }
    public bool QrEnabled { get; set; } = true;
    /// <summary>شناسهٔ گزارشی که این قالب پیش‌فرض آن است (NULL = پیش‌فرض نیست).</summary>
    public string? DefaultFor { get; set; }
    /// <summary>دامنهٔ «پیش‌فرض بودن» — NULL = سراسری/مشترک، غیر-NULL = همان شرکت.</summary>
    public int? CompanyId { get; set; }
}
