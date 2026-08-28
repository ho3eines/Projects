using System.Data;
using System.Drawing;
using System.Reflection;
using Stimulsoft.Base.Drawing;
using Stimulsoft.Report;
using Stimulsoft.Report.Components;
using Tarazin.Data;
using Tarazin.Data.Services;
using Tarazin.Models;
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
    private readonly PayrollCalculationService _payroll;

    private readonly UserSession _session;

    public BiReportService(DbService db, PayrollCalculationService payrollCalc, UserSession session)
    {
        _db = db;
        _payroll = payrollCalc;
        _session = session;
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

    /// <summary>
    /// ساخت فیش حقوق یک دوره (Stimulsoft) برای همهٔ کارمندان دوره.
    /// برای هر کارمند، تسهیم‌ها و کسورات از اسکریپت <c>payroll.PaySlipDetail</c> می‌آید و
    /// مالیات/خالصِ نهایی با <see cref="PayrollCalculationService"/> (جدول پلکانی) محاسبه می‌شود.
    /// چیدمان: سربرگ (عنوان + دوره) ← باند دادهٔ هر کارمند ← باند جمع سرصفحه‌ایات.
    /// </summary>
    public async Task<StiReport> BuildPaySlipReportAsync(int runId, CancellationToken ct = default)
    {
        var rows = (await _db.QueryAsync<PaySlipDetailRow>(
            "payroll", "PaySlipDetail", new { RunId = runId, CompanyId = _session.ActiveCompanyId }, ct)).ToList();
        if (rows.Count == 0)
            throw new InvalidOperationException("برای این دوره فیشی یافت نشد.");

        var period = rows[0].Period;
        var runNetTotal = rows[0].NetTotal;

        // محاسبهٔ مالیات/خالص هر کارمند از aggregations دوره (بدون تحت‌تکفل — پیش‌فرض).
        var lines = new List<PaySlipReportLine>();
        decimal sumEarnings = 0, sumDeductions = 0, sumTax = 0, sumNet = 0;
        foreach (var r in rows)
        {
            var calc = _payroll.ComputeFromTotals(r.TotalEarnings, r.TotalDeductions, 0);
            var line = new PaySlipReportLine(
                r.EmployeeName, r.EmployeeId,
                calc.Earnings, calc.Deductions, calc.IncomeTax, calc.NetPay);
            lines.Add(line);
            sumEarnings += line.Earnings;
            sumDeductions += line.Deductions;
            sumTax += line.Tax;
            sumNet += line.Net;
        }

        var table = ToSlipTable(lines);
        return BuildSlipReport(period, runNetTotal, table, sumEarnings, sumDeductions, sumTax, sumNet);
    }

    /// <summary>
    /// ساخت DataTable از فیش‌های محاسبه‌شده (همهٔ ستون‌ها متن فرمت‌شده).</summary>
    private static DataTable ToSlipTable(List<PaySlipReportLine> lines)
    {
        var table = new DataTable("Slips");
        table.Columns.Add("EmployeeName", typeof(string));
        table.Columns.Add("Earnings", typeof(string));
        table.Columns.Add("Deductions", typeof(string));
        table.Columns.Add("Tax", typeof(string));
        table.Columns.Add("Net", typeof(string));

        foreach (var l in lines)
            table.Rows.Add(l.EmployeeName, l.Earnings.ToString("N0"), l.Deductions.ToString("N0"),
                l.Tax.ToString("N0"), l.Net.ToString("N0"));
        return table;
    }

    private static StiReport BuildSlipReport(string period, decimal runNetTotal, DataTable table,
        decimal sumEarnings, decimal sumDeductions, decimal sumTax, decimal sumNet)
    {
        var navy = Color.FromArgb(94, 53, 177);
        var report = new StiReport { ReportName = $"فیش حقوق {period}" };
        var page = report.Pages[0];
        page.Margins = new StiMargins(25, 25, 25, 25);

        const double pageWidth = 800;
        const double colTop = 120;
        const double colHeight = 26;
        const double dataHeight = 24;

        // ── سربرگ: عنوان + متا + سرستون‌ها ──
        var headerBand = new StiPageHeaderBand { Name = "PageHeader", Height = colTop + colHeight + 8 };
        headerBand.Components.Add(new StiText
        {
            Name = "Title", Text = $"فیش حقوق دورهٔ {period}",
            Font = MakeFont(15, bold: true),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(navy),
            Width = pageWidth, Height = 34, Left = 0, Top = 4
        });
        headerBand.Components.Add(new StiText
        {
            Name = "Meta",
            Text = $"ترازین — سامانه یکپارچه مدیریت کسب‌وکار | چاپ: {DateTime.Now:yyyy/MM/dd HH:mm} | خالص کل دوره: {runNetTotal:N0} ریال",
            Font = MakeFont(8.5f, bold: false),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(Color.Gray),
            Width = pageWidth, Height = 20, Left = 0, Top = 40
        });
        headerBand.Components.Add(new StiText
        {
            Name = "Tip",
            Text = "مبالغ به ریال — مالیات بر اساس جدول پلکانی PayrollTaxService (بدون تحت تکفل) محاسبه می‌شود.",
            Font = MakeFont(7.5f, bold: false),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(Color.Gray),
            Width = pageWidth, Height = 16, Left = 0, Top = 62
        });

        string[] colNames = { "کارمند", "تسهیم‌ها", "کسورات", "مالیات", "خالص پرداختی" };
        double[] colWidths = { 280, 130, 130, 130, 130 };
        var x = 0d;
        for (var i = 0; i < colNames.Length; i++)
        {
            headerBand.Components.Add(new StiText
            {
                Name = "Col_" + i, Text = colNames[i],
                Font = MakeFont(9, bold: true),
                HorAlignment = StiTextHorAlignment.Center,
                TextBrush = new StiSolidBrush(Color.White),
                Brush = new StiSolidBrush(navy),
                Width = colWidths[i], Height = colHeight, Left = x, Top = colTop
            });
            x += colWidths[i];
        }

        // ── باند داده: فیش هر کارمند ──
        var dataBand = new StiDataBand { Name = "SlipsBand", DataSourceName = "Slips", Height = dataHeight };
        string[] dataCols = { "EmployeeName", "Earnings", "Deductions", "Tax", "Net" };
        x = 0;
        for (var i = 0; i < dataCols.Length; i++)
        {
            dataBand.Components.Add(new StiText
            {
                Name = "Val_" + dataCols[i],
                Text = "{Slips." + dataCols[i] + "}",
                Font = MakeFont(8.5f, bold: i == 0 || i == dataCols.Length - 1),
                HorAlignment = i == 0 ? StiTextHorAlignment.Left : StiTextHorAlignment.Center,
                Width = colWidths[i], Height = dataHeight, Left = x, Top = 0,
                CanGrow = true
            });
            x += colWidths[i];
        }

        // ── جمع‌بندی پایین گزارش ──
        var summaryBand = new StiFooterBand { Name = "Summary", Height = 120 };
        AddSlipTotal(summaryBand, "جمع تسهیم‌ها", sumEarnings, 0);
        AddSlipTotal(summaryBand, "جمع کسورات", sumDeductions, 26);
        AddSlipTotal(summaryBand, "جمع مالیات", sumTax, 52);
        AddSlipTotal(summaryBand, "جمع خالص پرداختی", sumNet, 78, emphasize: true);

        page.Components.Add(headerBand);
        page.Components.Add(dataBand);
        page.Components.Add(summaryBand);

        report.RegData("Slips", table);
        report.Dictionary.Synchronize();
        report.Render();

        return report;
    }

    /// <summary>ردیف جمع (برچسب + مقدار) در پایین فیش حقوق.</summary>
    private static void AddSlipTotal(StiBand band, string label, decimal value, double top, bool emphasize = false)
    {
        var accent = Color.FromArgb(94, 53, 177);
        var left = 430d;
        const double width = 370;
        band.Components.Add(new StiText
        {
            Name = "SlipSumL_" + label, Text = label,
            Font = MakeFont(9.5f, bold: true),
            Brush = new StiSolidBrush(emphasize ? Color.FromArgb(227, 242, 253) : Color.FromArgb(245, 245, 245)),
            Width = width * 0.5, Height = 24, Left = left, Top = top
        });
        band.Components.Add(new StiText
        {
            Name = "SlipSumV_" + label, Text = value.ToString("N0") + " ریال",
            Font = MakeFont(9.5f, bold: emphasize),
            HorAlignment = StiTextHorAlignment.Left,
            TextBrush = new StiSolidBrush(emphasize ? accent : Color.Black),
            Brush = new StiSolidBrush(emphasize ? Color.FromArgb(227, 242, 253) : Color.FromArgb(245, 245, 245)),
            Width = width * 0.5, Height = 24, Left = left + width * 0.5, Top = top
        });
    }

    /// <summary>یک ردیف فیش حقوق (محاسبه‌شده).</summary>
    private sealed record PaySlipReportLine(
        string EmployeeName, int EmployeeId,
        decimal Earnings, decimal Deductions, decimal Tax, decimal Net);

    /// <summary>
    /// ساخت گزارش Stimulsoft برای فاکتور خرید/فروش طلا از مدل چاپی.
    /// چیدمان: سربرگ (عنوان + اطلاعات فاکتور) ← باند دادهٔ ردیف‌ها ← باند جمع‌بندی
    /// (پایه/مالیات/کل + روش تسویه) ← فوتر صفحه (امضا + توضیح).
    /// </summary>
    public StiReport BuildInvoiceReport(GoldInvoicePrintModel model)
    {
        var isSale = model.InvoiceType == "Sale";
        var partyLabel = isSale ? "مشتری" : "تأمین‌کننده";
        var navy = Color.FromArgb(26, 35, 126);

        var report = new StiReport { ReportName = $"فاکتور {model.InvoiceNumber}" };
        var page = report.Pages[0];
        page.Margins = new StiMargins(25, 25, 25, 25);

        const double pageWidth = 800;
        const double colTop = 158;
        const double colHeight = 26;
        const double dataHeight = 24;

        // ── باند سربرگ صفحه: عنوان + متا + اطلاعات فاکتور + سرستون‌ها ──
        var headerBand = new StiPageHeaderBand { Name = "PageHeader", Height = colTop + colHeight + 8 };

        headerBand.Components.Add(new StiText
        {
            Name = "Title",
            Text = isSale ? "فاکتور فروش طلا و جواهرات" : "فاکتور خرید طلا و جواهرات",
            Font = MakeFont(15, bold: true),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(navy),
            Width = pageWidth, Height = 34, Left = 0, Top = 4
        });
        headerBand.Components.Add(new StiText
        {
            Name = "Meta",
            Text = $"ترازین — سامانه یکپارچه مدیریت کسب‌وکار | تاریخ چاپ: {DateTime.Now:yyyy/MM/dd HH:mm}",
            Font = MakeFont(8.5f, bold: false),
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(Color.Gray),
            Width = pageWidth, Height = 20, Left = 0, Top = 40
        });

        // جدول اطلاعات فاکتور (۲ ردیف × ۴ ستون + ردیف طرف حساب)
        var info = new List<(string Label, string Value)>
        {
            ("شماره فاکتور", model.InvoiceNumber),
            ("تاریخ صدور", model.InvoiceDate.ToString("yyyy/MM/dd")),
            ("نوع فاکتور", isSale ? "فروش" : "خرید"),
            ("کد تفصیلی", string.IsNullOrWhiteSpace(model.DetailCode) ? "—" : model.DetailCode!)
        };

        var labelBg = new StiSolidBrush(Color.FromArgb(245, 245, 245));
        var valueBg = new StiSolidBrush(Color.White);
        const double iw = pageWidth / 4;
        const double ih = 24;
        for (var i = 0; i < info.Count; i++)
        {
            headerBand.Components.Add(new StiText
            {
                Name = "InfoLabel_" + i, Text = info[i].Label + ":",
                Font = MakeFont(9, bold: true), Brush = labelBg,
                Width = iw, Height = ih, Left = i * iw, Top = 66
            });
            headerBand.Components.Add(new StiText
            {
                Name = "InfoValue_" + i, Text = info[i].Value,
                Font = MakeFont(9, bold: false), Brush = valueBg,
                Width = iw, Height = ih, Left = i * iw + iw / 2, Top = 66
            });
        }
        // طرف حساب (تمام‌عرض)
        headerBand.Components.Add(new StiText
        {
            Name = "PartyLabel", Text = partyLabel + ":",
            Font = MakeFont(9, bold: true), Brush = labelBg,
            Width = pageWidth * 0.25, Height = ih, Left = 0, Top = 92
        });
        headerBand.Components.Add(new StiText
        {
            Name = "PartyValue", Text = model.PartyName,
            Font = MakeFont(9.5f, bold: true), Brush = valueBg,
            Width = pageWidth * 0.75, Height = ih, Left = pageWidth * 0.25, Top = 92
        });

        // سرستون‌ها
        string[] colNames = { "ردیف", "نوع", "کالا / ارز", "مقدار", "نرخ / قیمت", "اجرت", "سود", "مالیات", "جمع ردیف" };
        double[] colWidths = { 40, 50, 190, 90, 110, 70, 70, 60, 120 };
        var x = 0d;
        for (var i = 0; i < colNames.Length; i++)
        {
            headerBand.Components.Add(new StiText
            {
                Name = "Col_" + i, Text = colNames[i],
                Font = MakeFont(9, bold: true),
                HorAlignment = StiTextHorAlignment.Center,
                TextBrush = new StiSolidBrush(Color.White),
                Brush = new StiSolidBrush(navy),
                Width = colWidths[i], Height = colHeight, Left = x, Top = colTop
            });
            x += colWidths[i];
        }

        // ── باند داده: ردیف‌های فاکتور ──
        var lines = ToLinesTable(model);
        var dataBand = new StiDataBand { Name = "LinesBand", DataSourceName = "Lines", Height = dataHeight };
        string[] dataCols = { "RowNum", "RowType", "Title", "QtyText", "RateText", "Workmanship", "Profit", "TaxText", "LineTotal" };
        x = 0;
        for (var i = 0; i < dataCols.Length; i++)
        {
            dataBand.Components.Add(new StiText
            {
                Name = "Val_" + dataCols[i],
                Text = "{Lines." + dataCols[i] + "}",
                Font = MakeFont(8.5f, bold: false),
                HorAlignment = i is 0 or 1 or 3 or 5 or 6 or 7 ? StiTextHorAlignment.Center : StiTextHorAlignment.Left,
                Width = colWidths[i], Height = dataHeight, Left = x, Top = 0,
                CanGrow = true
            });
            x += colWidths[i];
        }

        // ── باند جمع‌بندی: پایه/مالیات/کل + تسویه + سند ──
        var summaryBand = new StiFooterBand { Name = "Summary", Height = 175 };

        // جدول جمع (چپ) — ردیف‌های پایه/مالیات/کل
        double sx = pageWidth - 380;
        AddTotalRow(summaryBand, "جمع پایه", model.TotalBase.ToString("N0") + " ریال", sx, 0, 380, 24, light: true);
        AddTotalRow(summaryBand, $"مالیات ({model.TaxPct:0}%)", model.TotalTax.ToString("N0") + " ریال", sx, 26, 380, 24, light: true);
        AddTotalRow(summaryBand, "کل فاکتور", model.TotalAmount.ToString("N0") + " ریال", sx, 52, 380, 28, light: false);

        // جعبهٔ تسویه (تمام‌عرض)
        var settle = BuildSettlementText(model);
        summaryBand.Components.Add(new StiText
        {
            Name = "SettleTitle", Text = "روش تسویه",
            Font = MakeFont(9.5f, bold: true), TextBrush = new StiSolidBrush(navy),
            Width = pageWidth, Height = 20, Left = 0, Top = 88
        });
        summaryBand.Components.Add(new StiText
        {
            Name = "SettleBody", Text = settle,
            Font = MakeFont(8.5f, bold: false), Brush = new StiSolidBrush(Color.FromArgb(250, 250, 250)),
            Width = pageWidth, Height = 62, Left = 0, Top = 110,
            CanGrow = true
        });

        // ── فوتر صفحه: امضا + سند + توضیح ──
        var pageFooter = new StiPageFooterBand { Name = "PageFooter", Height = 110 };
        if (model.DocumentId > 0)
        {
            pageFooter.Components.Add(new StiText
            {
                Name = "DocNote",
                Text = $"سند حسابداری شماره: {model.DocumentId} | تاریخ: {model.InvoiceDate:yyyy/MM/dd}",
                Font = MakeFont(8f, bold: false), TextBrush = new StiSolidBrush(Color.Gray),
                Width = pageWidth, Height = 18, Left = 0, Top = 2
            });
        }

        string[] sigLabels = { $"امضای {partyLabel}", "مهر فروشگاه", "امضای فروشنده" };
        var sigW = pageWidth / 3d;
        for (var i = 0; i < sigLabels.Length; i++)
        {
            pageFooter.Components.Add(new StiText
            {
                Name = "Sig_" + i, Text = sigLabels[i],
                Font = MakeFont(9, bold: false),
                HorAlignment = StiTextHorAlignment.Center,
                Width = sigW - 20, Height = 20, Left = i * sigW + 10, Top = 34
            });
        }
        pageFooter.Components.Add(new StiText
        {
            Name = "Footer",
            Text = "این فاکتور توسط سامانه ترازین صادر شده است",
            Font = MakeFont(7.5f, bold: false), TextBrush = new StiSolidBrush(Color.Gray),
            HorAlignment = StiTextHorAlignment.Center,
            Width = pageWidth, Height = 16, Left = 0, Top = 88
        });

        page.Components.Add(headerBand);
        page.Components.Add(dataBand);
        page.Components.Add(summaryBand);
        page.Components.Add(pageFooter);

        report.RegData("Lines", lines);
        report.Dictionary.Synchronize();
        report.Render();

        return report;
    }

    /// <summary>ساخت DataTable از ردیف‌های فاکتور (همهٔ ستون‌ها متن فرمت‌شده برای نمایش).</summary>
    private static DataTable ToLinesTable(GoldInvoicePrintModel model)
    {
        var isSale = model.InvoiceType == "Sale";
        var table = new DataTable("Lines");
        table.Columns.Add("RowNum", typeof(string));
        table.Columns.Add("RowType", typeof(string));
        table.Columns.Add("Title", typeof(string));
        table.Columns.Add("QtyText", typeof(string));
        table.Columns.Add("RateText", typeof(string));
        table.Columns.Add("Workmanship", typeof(string));
        table.Columns.Add("Profit", typeof(string));
        table.Columns.Add("TaxText", typeof(string));
        table.Columns.Add("LineTotal", typeof(string));

        for (var i = 0; i < model.Lines.Count; i++)
        {
            var line = model.Lines[i];
            var isGold = line.RowType == "Gold";
            var lineBase = isGold
                ? Math.Round(line.Qty * line.Price + line.Workmanship + line.Profit, 0)
                : Math.Round(line.Qty * line.ResolvedRate, 0);
            var lineTax = line.TaxEnabled
                ? (isGold
                    ? Math.Round((line.Qty * line.Price + line.Profit) * model.TaxPct / 100m + line.Workmanship * model.LaborTaxPct / 100m, 0)
                    : Math.Round(line.Qty * line.ResolvedRate * model.TaxPct / 100m, 0))
                : 0;

            table.Rows.Add(
                (i + 1).ToString(),
                isGold ? "طلا" : "ارز",
                line.Title,
                line.Qty.ToString(isGold ? "N3" : "N2") + (isGold ? " گرم" : " " + line.CurrencyCode),
                (isGold ? line.Price : line.ResolvedRate).ToString("N0"),
                isSale && isGold ? line.Workmanship.ToString("N0") : "—",
                isSale && isGold ? line.Profit.ToString("N0") : "—",
                lineTax > 0 ? "✓" : "—",
                (lineBase + lineTax).ToString("N0"));
        }
        return table;
    }

    /// <summary>متن چندخطی روش تسویه (فقط موارد غیرصفر).</summary>
    private static string BuildSettlementText(GoldInvoicePrintModel model)
    {
        var lines = new List<string>();
        if (model.PayCash > 0) lines.Add($"💵 نقدی (صندوق): {model.PayCash:N0} ریال");
        if (model.PayBank > 0) lines.Add($"🏦 پرداخت بانکی: {model.PayBank:N0} ریال");
        if (model.PayChequeAmount > 0)
            lines.Add($"📄 چک شماره {model.ChequeNumber} — {model.ChequeBankName ?? "—"}: {model.PayChequeAmount:N0} ریال"
                      + (model.ChequeDueDate.HasValue ? $" (سررسید: {model.ChequeDueDate.Value:yyyy/MM/dd})" : ""));
        if (model.PayGoldGram > 0)
            lines.Add($"🥇 طلا تحویلی: {model.PayGoldGram:N3} گرم × {model.GoldPrice:N0} = {(model.PayGoldGram * model.GoldPrice):N0} ریال");
        if (model.PayCurrencyQty > 0)
            lines.Add($"💱 ارز {model.PayCurrencyCode}: {model.PayCurrencyQty:N2} × {model.PayCurrencyRate:N0} = {(model.PayCurrencyQty * model.PayCurrencyRate):N0} ریال");
        if (model.BalanceRial > 0) lines.Add($"⏳ نسیه (باقیمانده): {model.BalanceRial:N0} ریال");
        return lines.Count == 0 ? "تسویه‌ای ثبت نشده است." : string.Join("\n", lines);
    }

    /// <summary>ردیف «برچسب | مقدار» در جدول جمع‌بندی.</summary>
    private static void AddTotalRow(StiBand band, string label, string value, double left, double top, double width, double height, bool light)
    {
        band.Components.Add(new StiText
        {
            Name = "SumL_" + label, Text = label,
            Font = MakeFont(9, bold: true),
            Brush = new StiSolidBrush(light ? Color.FromArgb(227, 242, 253) : Color.FromArgb(232, 245, 233)),
            Width = width * 0.5, Height = height, Left = left, Top = top
        });
        band.Components.Add(new StiText
        {
            Name = "SumV_" + label, Text = value,
            Font = MakeFont(9.5f, bold: !light),
            HorAlignment = StiTextHorAlignment.Left,
            TextBrush = new StiSolidBrush(light ? Color.Black : Color.FromArgb(46, 125, 50)),
            Brush = new StiSolidBrush(light ? Color.FromArgb(227, 242, 253) : Color.FromArgb(232, 245, 233)),
            Width = width * 0.5, Height = height, Left = left + width * 0.5, Top = top
        });
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
