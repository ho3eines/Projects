using System.Globalization;
using System.Net;
using System.Text;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// رندرر «برگهٔ چاپی» موتور چاپ عمومی — از روی قالب + داده، HTML خالص RTL می‌سازد
/// (بدون هیچ کامپوننت MudBlazor داخل برگه) تا خروجی چاپ مرورگر و پیش‌نمایش دقیقاً
/// تمیز و راست‌چین باشد. باندها:
///   ۱) هدر اطلاعات شرکت (لوگو/نام/آدرس) + QR   — در چاپ روی همهٔ صفحات تکرار می‌شود
///   ۲) هدر گزارش (عنوان/زیرعنوان/بازه + هدر داده)
///   ۳) هدر ستون‌ها (thead — در چاپ روی همهٔ صفحات تکرار می‌شود)
///   ۴) دیتیل (ردیف‌های لیست، با پشتیبانی indent برای سلسله‌مراتب)
///   ۵) فوتر گزارش (جمع‌های ستون‌های Total + فیلدهای فوتر)
///   ۶) فوتر صفحه (شماره صفحه — با CSS)
/// </summary>
public static class PrintSheetRenderer
{
    private static readonly CultureInfo Fa = CultureInfo.GetCultureInfo("fa-IR");

    /// <summary>ساخت HTML کامل برگهٔ چاپ (فقط ناحیهٔ چاپ — قواعد چاپ در app.css).</summary>
    public static string BuildHtml(PrintTemplateDef tpl, PrintDataModel data)
    {
        var sb = new StringBuilder(4096);
        sb.Append("<div dir=\"rtl\" class=\"tpl-sheet");

        if (tpl.Orientation == PrintOrientation.Landscape)
            sb.Append(" tpl-sheet--landscape");
        if (tpl.PaperSize == PrintPaperSize.A5)
            sb.Append(" tpl-sheet--a5");

        sb.Append($"\" style=\"font-size:{tpl.FontSizePt:0.#}pt\">");

        // ═══ باند ۱: هدر اطلاعات شرکت (در چاپ: fixed → تکرار روی همهٔ صفحات) ═══
        if (tpl.ShowCompanyHeader)
            sb.Append(BuildCompanyHeader(tpl, data));

        // ═══ باند ۲: هدر گزارش ═══
        sb.Append("<div class=\"tpl-report-header\">");
        var title = string.IsNullOrWhiteSpace(data.Title) ? tpl.ReportTitle : data.Title;
        if (!string.IsNullOrWhiteSpace(title))
            sb.Append($"<div class=\"tpl-title\">{Enc(title)}</div>");
        if (!string.IsNullOrWhiteSpace(data.Subtitle) || !string.IsNullOrWhiteSpace(tpl.ReportSubtitle))
            sb.Append($"<div class=\"tpl-subtitle\">{Enc(string.IsNullOrWhiteSpace(data.Subtitle) ? tpl.ReportSubtitle! : data.Subtitle)}</div>");
        if (!string.IsNullOrWhiteSpace(data.RangeText))
            sb.Append($"<div class=\"tpl-range\">{Enc(data.RangeText)}</div>");

        sb.Append(BuildMetaGrid(tpl, data));
        sb.Append("</div>");

        // ═══ باند ۳+۴: جدول دیتیل ═══
        sb.Append("<table class=\"tpl-table\"><thead><tr>");
        foreach (var col in tpl.Columns)
        {
            var align = AlignClass(col.Align);
            sb.Append($"<th class=\"tpl-th {align}\" style=\"width:{Math.Max(col.Width, 20)}px\">{Enc(col.Title)}</th>");
        }
        sb.Append("</tr></thead><tbody>");

        if (data.Rows.Count == 0)
        {
            sb.Append("<tr><td class=\"tpl-td tpl-empty\" colspan=\"")
              .Append(Math.Max(tpl.Columns.Count, 1))
              .Append("\">داده‌ای برای چاپ وجود ندارد.</td></tr>");
        }
        else
        {
            foreach (var row in data.Rows)
            {
                var indent = row.TryGetValue("__indent", out var iv) && iv is int i ? i : 0;
                var bg = row.TryGetValue("__bg", out var bv) ? Convert.ToString(bv, Fa) : null;
                var bold = row.TryGetValue("__bold", out var bo) && bo is true;

                sb.Append("<tr class=\"tpl-tr\"");
                if (!string.IsNullOrWhiteSpace(bg))
                    sb.Append($" style=\"background:{Enc(bg)}\"");
                sb.Append('>');

                for (var c = 0; c < tpl.Columns.Count; c++)
                {
                    var col = tpl.Columns[c];
                    var value = FormatValue(row, col, Fa);
                    var style = new StringBuilder();
                    if (c == 0 && indent > 0)
                        style.Append($"padding-inline-start:{indent * 14}px;");
                    var cls = $"tpl-td {AlignClass(col.Align)}";
                    var fontWeight = col.Bold || bold ? ";font-weight:600" : "";
                    sb.Append($"<td class=\"{cls}\" style=\"{style}{fontWeight.TrimStart(';')}\">")
                      .Append(string.IsNullOrEmpty(value) ? "&nbsp;" : value)
                      .Append("</td>");
                }
                sb.Append("</tr>");
            }
        }
        sb.Append("</tbody></table>");

        // ═══ باند ۵: فوتر گزارش (جمع‌ها) ═══
        if (tpl.ShowReportFooter)
            sb.Append(BuildReportFooter(tpl, data));

        // ═══ باند ۶: فوتر صفحه (در چاپ: fixed → تکرار) ═══
        if (tpl.ShowPageFooter)
        {
            sb.Append("<div class=\"tpl-page-footer\">")
              .Append("<span>").Append(Enc(string.IsNullOrWhiteSpace(data.CompanyName) ? "ترازین" : data.CompanyName)).Append("</span>")
              .Append("<span class=\"tpl-page-no\">صفحه <span class=\"tpl-counter\">1</span></span>")
              .Append("</div>");
        }

        sb.Append("</div>");
        return sb.ToString();
    }

    private static string BuildCompanyHeader(PrintTemplateDef tpl, PrintDataModel data)
    {
        var sb = new StringBuilder();
        sb.Append("<div class=\"tpl-company-header\">");

        var logo = string.IsNullOrWhiteSpace(data.LogoPath)
            ? "_content/Tarazin.Ui/brand/logo.svg"
            : data.LogoPath;
        sb.Append($"<img src=\"{EncAttr(logo)}\" alt=\"\" class=\"tpl-logo\" />");

        sb.Append("<div class=\"tpl-brand\">");
        sb.Append($"<div class=\"tpl-brand-name\">{Enc(data.CompanyName)}</div>");
        if (!string.IsNullOrWhiteSpace(data.CompanyAddress))
            sb.Append($"<div class=\"tpl-brand-address\">آدرس: {Enc(data.CompanyAddress)}</div>");
        sb.Append("</div>");

        if (tpl.QrEnabled && data.QrEnabled && !string.IsNullOrWhiteSpace(data.QrPayload))
        {
            sb.Append("<div class=\"tpl-qr\" style=\"margin-inline-start:auto\">")
              .Append($"<qr-fill data-payload=\"{EncAttr(data.QrPayload)}\"></qr-fill>")
              .Append("</div>");
        }
        sb.Append("</div>");
        return sb.ToString();
    }

    /// <summary>شبکهٔ هدر داده — برچسب‌های قالب با مقادیر داده جفت می‌شوند.</summary>
    private static string BuildMetaGrid(PrintTemplateDef tpl, PrintDataModel data)
    {
        if (tpl.MetaFields.Count == 0 && data.MetaFields.Count == 0)
            return "";

        var fields = new List<PrintMetaField>();
        var max = Math.Max(tpl.MetaFields.Count, data.MetaFields.Count);
        for (var i = 0; i < max; i++)
        {
            var def = i < tpl.MetaFields.Count ? tpl.MetaFields[i] : new PrintMetaField();
            var val = i < data.MetaFields.Count && data.MetaFields[i].Value is not null
                ? data.MetaFields[i].Value
                : def.Value;
            fields.Add(new PrintMetaField
            {
                // برچسب واقعیِ داده اگر مقداری داشته باشد اولویت دارد؛ لیبل قالب فقط جایگ خالی است.
                Label = i < data.MetaFields.Count && !string.IsNullOrWhiteSpace(data.MetaFields[i].Label)
                    ? data.MetaFields[i].Label
                    : def.Label,
                Value = val,
                Bold = i < data.MetaFields.Count ? data.MetaFields[i].Bold : def.Bold
            });
        }
        fields.RemoveAll(f => string.IsNullOrWhiteSpace(f.Label) && string.IsNullOrWhiteSpace(f.Value));

        var sb = new StringBuilder();
        sb.Append("<div class=\"tpl-meta\">");
        foreach (var f in fields)
        {
            sb.Append("<div class=\"tpl-meta-item\">");
            if (!string.IsNullOrWhiteSpace(f.Label))
                sb.Append($"<span class=\"tpl-meta-label\">{Enc(f.Label)}:</span> ");
            sb.Append($"<span class=\"tpl-meta-value\"{(f.Bold ? " style=\"font-weight:600\"" : "")}>")
              .Append(Enc(string.IsNullOrWhiteSpace(f.Value) ? "—" : f.Value))
              .Append("</span>");
            sb.Append("</div>");
        }
        sb.Append("</div>");
        return sb.ToString();
    }

    private static string BuildReportFooter(PrintTemplateDef tpl, PrintDataModel data)
    {
        var sb = new StringBuilder();
        sb.Append("<div class=\"tpl-report-footer\">");

        // جمع خودکار ستون‌های Total
        foreach (var col in tpl.Columns.Where(c => c.Total))
        {
            decimal sum = 0;
            foreach (var row in data.Rows)
            {
                if (row.TryGetValue(col.Key, out var v) && TryToDecimal(v, out var d))
                    sum += d;
            }
            sb.Append($"<div class=\"tpl-total\"><span class=\"tpl-meta-label\">جمع {Enc(col.Title)}:</span> ")
              .Append($"<span class=\"tpl-meta-value\" style=\"font-weight:600\">{FormatDecimal(sum, col.Format, Fa)}</span></div>");
        }

        foreach (var f in data.FooterFields)
        {
            sb.Append($"<div class=\"tpl-total\"><span class=\"tpl-meta-label\">{Enc(f.Label)}:</span> ")
              .Append($"<span class=\"tpl-meta-value\" style=\"font-weight:600\">{Enc(f.Value ?? "—")}</span></div>");
        }

        sb.Append("</div>");
        return sb.ToString();
    }

    // ─────────────────────────── فرمت‌دهی مقادیر ───────────────────────────

    private static string FormatValue(PrintRow row, PrintColumnDef col, CultureInfo culture)
    {
        if (!row.TryGetValue(col.Key, out var value) || value is null)
            return "";

        if (value is IFormattable f && !string.IsNullOrWhiteSpace(col.Format))
            return f.ToString(col.Format, culture);

        if (TryToDecimal(value, out var d))
            return FormatDecimal(d, col.Format, culture);

        return Convert.ToString(value, culture) ?? "";
    }

    private static string FormatDecimal(decimal d, string? format, CultureInfo culture)
        => string.IsNullOrWhiteSpace(format) ? d.ToString(culture) : d.ToString(format, culture);

    private static bool TryToDecimal(object? value, out decimal d)
    {
        switch (value)
        {
            case decimal m: d = m; return true;
            case int i: d = i; return true;
            case long l: d = l; return true;
            case double db: d = (decimal)db; return true;
            case float fl: d = (decimal)fl; return true;
            case string s when decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, out d): return true;
            default: d = 0; return false;
        }
    }

    private static string AlignClass(PrintAlign align) => align switch
    {
        PrintAlign.Center => "tpl-center",
        PrintAlign.End => "tpl-end",
        _ => "tpl-start"
    };

    private static string Enc(string? value)
        => string.IsNullOrEmpty(value) ? "" : WebUtility.HtmlEncode(value);

    private static string EncAttr(string? value)
        => string.IsNullOrEmpty(value) ? "" : WebUtility.HtmlEncode(value).Replace("\"", "&quot;");
}
