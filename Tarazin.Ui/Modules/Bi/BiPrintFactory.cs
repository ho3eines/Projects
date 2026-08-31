using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// تبدیل یک گزارش BI (تعریف کاتالوگ + ردیف‌های واقعی از اسکریپت نامدار) به
/// قالب/دادهٔ موتور چاپ عمومی — منبع واحد برای صفحهٔ گزارش‌ها (`/bi/reports`)
/// و صفحهٔ تست توسعه (`/dev/bireport`) تا خروجی هر دو همیشه یکسان باشد.
/// </summary>
public static class BiPrintFactory
{
    /// <summary>ساخت قالب پویا از ستون‌های تعریف گزارش (اندازه A4، جهت بر اساس تعداد ستون).</summary>
    public static PrintTemplateDef BuildTemplate(BiReportDefinition def, int rowCount)
    {
        var tpl = new PrintTemplateDef
        {
            Id = "bi." + def.Key,
            Name = def.Title,
            Module = "bi",
            PaperSize = PrintPaperSize.A4,
            Orientation = rowCount > 0 && def.ColumnTitles is { Count: > 6 }
                ? PrintOrientation.Landscape
                : PrintOrientation.Portrait,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = def.ColumnTitles is { Count: <= 4 },
            QrEnabled = false,
            ReportTitle = def.Title,
            MetaFields = new List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "تعداد ردیف", Bold = true }
            },
            Columns = def.ColumnTitles?.Select(kv => new PrintColumnDef
            {
                Key = kv.Key,
                Title = kv.Value,
                Width = kv.Value.Contains("مبلغ") || kv.Value.Contains("ارزش") || kv.Value.Contains("سود") || kv.Value.Contains("درصد")
                    ? 100 : 90,
                Align = kv.Value.Contains("مبلغ") || kv.Value.Contains("ارزش") || kv.Value.Contains("سود")
                    ? PrintAlign.End : PrintAlign.Start,
                Format = kv.Value.Contains("مبلغ") || kv.Value.Contains("ارزش") || kv.Value.Contains("سود") || kv.Value.Contains("درصد") ? "N0" : null,
                Bold = kv.Value == "شماره"
            }).ToList() ?? new()
        };
        return tpl;
    }

    /// <summary>ساخت دادهٔ چاپ از ردیف‌های واقعی اسکریپت + بازهٔ تاریخ.</summary>
    public static PrintDataModel BuildData(BiReportDefinition def, IReadOnlyList<dynamic> rows, DateTime? from, DateTime? to)
    {
        var data = new PrintDataModel
        {
            CompanyName = "ترازین — سامانه یکپارچه مدیریت کسب‌وکار",
            Title = def.Title,
            Subtitle = def.Subtitle,
            RangeText = $"{from:yyyy/MM/dd} تا {to:yyyy/MM/dd}",
            QrEnabled = false
        };
        data.MetaFields.Add(new PrintMetaField { Label = "بازه", Value = $"{from:yyyy/MM/dd} تا {to:yyyy/MM/dd}", Bold = true });
        data.MetaFields.Add(new PrintMetaField { Label = "تعداد ردیف", Value = rows.Count.ToString("N0"), Bold = true });

        foreach (var r in rows)
        {
            var row = new PrintRow();
            if (def.ColumnTitles is not null)
            {
                foreach (var col in def.ColumnTitles.Keys)
                    row[col] = GetDynamic(r, col);
            }
            data.Rows.Add(row);
        }
        return data;
    }

    /// <summary>خواندن مقدار ستون از یک ردیف داینامیک (دیکشنری یا پراپرتی).</summary>
    public static object? GetDynamic(dynamic row, string key)
    {
        try
        {
            var dict = (IDictionary<string, object>)row;
            return dict.TryGetValue(key, out var v) ? v : null;
        }
        catch
        {
            try
            {
                var p = row.GetType().GetProperty(key);
                return p?.GetValue(row);
            }
            catch
            {
                return null;
            }
        }
    }
}
