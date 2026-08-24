using System.Data;
using System.Drawing;
using System.Reflection;
using Stimulsoft.Base.Drawing;
using Stimulsoft.Report;
using Stimulsoft.Report.Components;
using Tarazin.Data;
// فونت گزارش از فاساد cross-platform خود Stimulsoft (Stimulsoft.Drawing) می‌آید —
// در ویندوز روی System.Drawing و در اندروید/iOS روی SixLabors.ImageSharp اجرا می‌شود.
using StiFont = Stimulsoft.Drawing.Font;

namespace Tarazin.Services;

/// <summary>
/// سرویس چاپ و گزارش با Stimulsoft (PRD BI §121 — «چاپ‌ها با Stimulsoft»).
///
/// معماری:
/// - داده فقط از اسکریپت‌های نامدار موجود (DbService) می‌آید — هیچ SQL در اینجا نیست.
/// - هر گزارش = یک تعریف (BiReportDefinition) شامل اسکریپت + پارامترها + عنوان فارسی ستون‌ها.
/// - سرویس، DataTable را از خروجی اسکریپت می‌سازد و یک StiReport جدولی (سربرگ + باند داده)
///   به‌صورت برنامه‌نویسی می‌سازد؛ سپس در <c>StiBlazorViewer</c> رندر/چاپ/خروجی PDF-Excel می‌شود.
/// - فونت/رنگ اجزای گزارش از API رسمی Stimulsoft .NET استفاده می‌کند:
///   <c>StiText.Font</c> از نوع <c>Stimulsoft.Drawing.Font</c> (فاساد cross-platform خود Stimulsoft)
///   و براش‌ها <c>StiSolidBrush(Color)</c> هستند؛ در MAUI اندروید/iOS همین فاساد
///   روی SixLabors.ImageSharp اجرا می‌شود (نه System.Drawing.Common ویندوزی).
///
/// نکتهٔ لایسنس: بدون کلید لایسنس Stimulsoft، خروجی با واترمارک آزمایشی رندر می‌شود؛
/// برای تولید باید لایسنس خریداری و در Program.cs ثبت شود (مستند در docs/BI_MODULE.md).
/// </summary>
public sealed class BiReportService
{
    private readonly DbService _db;

    public BiReportService(DbService db)
    {
        _db = db;
    }

    /// <summary>ساخت و رندر گزارش Stimulsoft از خروجی اسکریپت نامدار.</summary>
    public async Task<StiReport> BuildAsync(BiReportDefinition def, CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync<dynamic>(def.Schema, def.Script, def.Params, ct);
        var table = ToDataTable(rows, def.Script);
        return BuildTableReport(def.Title, def.Subtitle, table, def.ColumnTitles);
    }

    /// <summary>
    /// ساخت یک گزارش آزمایشی از دادهٔ ثابت (بدون نیاز به دیتابیس/ورود) — برای تست
    /// رندر و فونت روی هر پلتفرم (به‌ویژه MAUI اندروید/iOS). دقیقاً از همان مسیر
    /// تولیدی <see cref="BuildTableReport"/> عبور می‌کند تا فاساد cross-platform
    /// فونت (Stimulsoft.Drawing) در عمل تست شود.
    /// </summary>
    public StiReport BuildDemoReport()
    {
        var table = new DataTable("DemoGoldSales");
        table.Columns.Add("InvoiceNumber", typeof(string));
        table.Columns.Add("InvoiceDate", typeof(string));
        table.Columns.Add("CustomerName", typeof(string));
        table.Columns.Add("ItemTitle", typeof(string));
        table.Columns.Add("WeightGram", typeof(string));
        table.Columns.Add("TotalAmount", typeof(string));

        table.Rows.Add("1001", "1403/05/12", "مشتری آزمایشی یک", "انگشتر طلا", "4.25", "82,500,000");
        table.Rows.Add("1002", "1403/05/13", "مشتری آزمایشی دو", "گردنبند طلا", "8.10", "158,900,000");
        table.Rows.Add("1003", "1403/05/14", "مشتری آزمایشی سه", "دستبند طلا", "12.40", "241,000,000");

        return BuildTableReport(
            "گزارش آزمایشی فروش طلا (بدون دیتابیس)",
            "دادهٔ ثابت — تست رندر Stimulsoft.Drawing روی همین دستگاه",
            table,
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                ["InvoiceNumber"] = "شماره",
                ["InvoiceDate"] = "تاریخ",
                ["CustomerName"] = "مشتری",
                ["ItemTitle"] = "جنس",
                ["WeightGram"] = "وزن (گرم)",
                ["TotalAmount"] = "مبلغ (ریال)",
            });
    }

    /// <summary>
    /// نام فونتِ واقعاً استفاده‌شده در رندر برای اولین <see cref="StiText"/> گزارش.
    /// از فیلد داخلی <c>sixFont</c> (SixLabors) می‌خواند تا نام resolve شده را بدهد —
    /// یعنی وقتی «Vazirmatn» روی دستگاه نصب نباشد، «Roboto» فالتبک برمی‌گردد؛ چون
    /// <c>Font.Name</c> عمومی فقط نام درخواستی را می‌دهد، نه نام واقعی.
    /// </summary>
    public static string? GetActualFontName(StiReport report)
    {
        if (report is null) return null;
        var sixFontField = typeof(StiFont).GetField("sixFont", BindingFlags.NonPublic | BindingFlags.Instance);
        foreach (var component in report.GetComponents())
        {
            if (component is not StiText text || text.Font is null) continue;
            var sixFont = sixFontField?.GetValue(text.Font);
            var family = sixFont?.GetType().GetProperty("Family")?.GetValue(sixFont);
            var name = family?.GetType().GetProperty("Name")?.GetValue(family)?.ToString();
            if (!string.IsNullOrWhiteSpace(name)) return name;
        }
        return null;
    }

    /// <summary>تبدیل خروجی Dapper به DataTable (نام ستون‌ها از aliases اسکریپت).</summary>
    private static DataTable ToDataTable(IReadOnlyList<dynamic> rows, string name)
    {
        var table = new DataTable(name);
        if (rows.Count == 0)
            return table;

        var first = (IDictionary<string, object>)rows[0]!;
        foreach (var key in first.Keys)
            table.Columns.Add(key, typeof(object));

        foreach (var row in rows)
        {
            var dict = (IDictionary<string, object>)row!;
            var dr = table.NewRow();
            foreach (var key in dict.Keys)
                dr[key] = dict[key] ?? DBNull.Value;
            table.Rows.Add(dr);
        }
        return table;
    }

    /// <summary>
    /// ساخت گزارش جدولی (سربرگ + ردیف سرستون + باند داده) با مدل شیء Stimulsoft.
    /// واحد مختصات: صدم اینچ (پیش‌فرض StiReport).
    /// </summary>
    /// <summary>
    /// ساخت فونت گزارش با فاساد cross-platform Stimulsoft.Drawing.
    /// نام فونت «Vazirmatn» است (همان فونت UI پروژه). موتور رندر (پیش‌فرض ImageSharp) فونت را
    /// از فایل‌های فونت نصب‌شدهٔ همان دستگاه پیدا می‌کند؛ اگر پیدا نشد (معمولاً در اندروید/IOS و
    /// سرورهای بدون نصب فونت) خودکار به Roboto جاسازیشدهٔ Stimulsoft برمی‌گردد تا رندر همیشه
    /// سالم بماند — یعنی خروجی روی دستگاه‌های بدون Vazirmatn یکسان (Roboto) است.
    /// امضای سازندهٔ آن از <see cref="FontStyle"/> (System.Drawing) استفاده می‌کند که
    /// فقط یک enum است؛ خود رندر در اندروید/iOS توسط SixLabors انجام می‌شود، پس CA1416
    /// در اینجا مثبتِ کاذب است و به‌صورت موضعی (فقط داخل همین متد) غیرفعال شده.
    /// </summary>
    private static StiFont MakeFont(float size, bool bold)
    {
#pragma warning disable CA1416 // FontStyle فقط enum است؛ پیاده‌سازی واقعی در Stimulsoft.Drawing (SixLabors) است
        return new StiFont("Vazirmatn", size, bold ? FontStyle.Bold : FontStyle.Regular);
#pragma warning restore CA1416
    }

    private static StiReport BuildTableReport(string title, string? subtitle, DataTable table,
        IReadOnlyDictionary<string, string>? columnTitles)
    {
        var report = new StiReport { ReportName = title };
        var page = report.Pages[0];
        page.Margins = new StiMargins(25, 25, 25, 25);

        const int pageWidth = 800;
        const int colTop = 90;
        const int colHeight = 28;
        const int dataHeight = 25;

        // ── باند سربرگ: عنوان + زیرعنوان + سرستون‌ها ──────────────────────
        var headerBand = new StiPageHeaderBand { Name = "HeaderBand", Height = 160 };

        headerBand.Components.Add(new StiText
        {
            Name = "Title",
            Text = title,
            Font = MakeFont(14, bold: true),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(Color.FromArgb(94, 53, 177)),
            Width = pageWidth, Height = 35, Left = 0, Top = 5
        });

        var meta = string.IsNullOrWhiteSpace(subtitle)
            ? $"تهیه شده در {DateTime.Now:yyyy/MM/dd HH:mm} — ترازین"
            : $"{subtitle} — تهیه شده در {DateTime.Now:yyyy/MM/dd HH:mm}";
        headerBand.Components.Add(new StiText
        {
            Name = "Meta",
            Text = meta,
            Font = MakeFont(9, bold: false),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(Color.Gray),
            Width = pageWidth, Height = 22, Left = 0, Top = 42
        });

        // سرستون‌ها
        var colWidth = pageWidth / (double)(table.Columns.Count == 0 ? 1 : table.Columns.Count);
        var x = 0d;
        foreach (DataColumn column in table.Columns)
        {
            var header = columnTitles is not null && columnTitles.TryGetValue(column.ColumnName, out var fa)
                ? fa : column.ColumnName;
            headerBand.Components.Add(new StiText
            {
                Name = "Col_" + column.ColumnName,
                Text = header,
                Font = MakeFont(10, bold: true),
                HorAlignment = StiTextHorAlignment.Center,
                TextBrush = new StiSolidBrush(Color.White),
                Brush = new StiSolidBrush(Color.FromArgb(94, 53, 177)),
                Width = colWidth, Height = colHeight, Left = x, Top = colTop
            });
            x += colWidth;
        }

        // ── باند داده ─────────────────────────────────────────────────────
        var dataBand = new StiDataBand
        {
            Name = "DataBand",
            DataSourceName = table.TableName,
            Height = dataHeight
        };

        x = 0;
        foreach (DataColumn column in table.Columns)
        {
            dataBand.Components.Add(new StiText
            {
                Name = "Val_" + column.ColumnName,
                // اتصال به ستون داده از طریق عبارت {Table.Column} انجام می‌شود (الگوی رسمی Stimulsoft)
                Text = "{" + table.TableName + "." + column.ColumnName + "}",
                Font = MakeFont(9, bold: false),
                TextBrush = new StiSolidBrush(Color.Black),
                Width = colWidth, Height = dataHeight, Left = x, Top = 0,
                CanGrow = true
            });
            x += colWidth;
        }

        page.Components.Add(headerBand);
        page.Components.Add(dataBand);

        // دادهٔ واقعی ← ثبت و رندر
        report.RegData(table.TableName, table);
        // همگام‌سازی دیکشنری با دادهٔ ثبت‌شده تا DataBand به ستون‌ها دسترسی داشته باشد
        report.Dictionary.Synchronize();
        report.Render();

        return report;
    }
}

/// <summary>تعریف یک گزارش قابل چاپ (کاتالوگ).</summary>
public sealed record BiReportDefinition(
    string Key,
    string Title,
    string? Subtitle,
    string Schema,
    string Script,
    Dictionary<string, object?> Params,
    IReadOnlyDictionary<string, string>? ColumnTitles);
