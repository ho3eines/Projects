using System.Data;
using Stimulsoft.Base.Drawing;
using Stimulsoft.Report;
using Stimulsoft.Report.Components;
using Tarazin.Data;

namespace Tarazin.Services;

/// <summary>
/// سرویس چاپ و گزارش با Stimulsoft (PRD BI §121 — «چاپ‌ها با Stimulsoft»).
///
/// معماری:
/// - داده فقط از اسکریپت‌های نامدار موجود (DbService) می‌آید — هیچ SQL در اینجا نیست.
/// - هر گزارش = یک تعریف (BiReportDefinition) شامل اسکریپت + پارامترها + عنوان فارسی ستون‌ها.
/// - سرویس، DataTable را از خروجی اسکریپت می‌سازد و یک StiReport جدولی (سربرگ + باند داده)
///   به‌صورت برنامه‌نویسی می‌سازد؛ سپس در <c>StiBlazorViewer</c> رندر/چاپ/خروجی PDF-Excel می‌شود.
/// - بدون وابستگی به System.Drawing (سازگار با همهٔ پلتفرم‌ها).
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
    private static StiReport BuildTableReport(string title, string subtitle, DataTable table,
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
            FontSize = 14,
            FontBold = true,
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(StiColor.FromArgb(94, 53, 177)),
            Width = pageWidth, Height = 35, Left = 0, Top = 5
        });

        var meta = string.IsNullOrWhiteSpace(subtitle)
            ? $"تهیه شده در {DateTime.Now:yyyy/MM/dd HH:mm} — ترازین"
            : $"{subtitle} — تهیه شده در {DateTime.Now:yyyy/MM/dd HH:mm}";
        headerBand.Components.Add(new StiText
        {
            Name = "Meta",
            Text = meta,
            FontSize = 9,
            HorAlignment = StiTextHorAlignment.Center,
            TextBrush = new StiSolidBrush(StiColor.Gray),
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
                FontSize = 10,
                FontBold = true,
                HorAlignment = StiTextHorAlignment.Center,
                TextBrush = new StiSolidBrush(StiColor.White),
                Brush = new StiSolidBrush(StiColor.FromArgb(94, 53, 177)),
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
                DataColumnName = column.ColumnName,
                FontSize = 9,
                TextBrush = new StiSolidBrush(StiColor.Black),
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
