using System;
using System.Linq;
using Tarazin.Models;
using Tarazin.Services;
using Xunit;

namespace Tarazin.Tests;

public sealed class PrintEngineTests
{
    [Fact]
    public void BuildTemplatePdf_works()
    {
        var svc = new PdfReportService();
        var tpl = new PrintTemplateDef
        {
            Id = "treasury.cheques",
            Name = "چکها",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            MetaFields = new System.Collections.Generic.List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "وضعیت", Bold = false }
            },
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "ChequeNumber", Title = "شماره چک", Width = 90, Bold = true },
                new() { Key = "DueDate", Title = "سررسید", Width = 85 },
                new() { Key = "Amount", Title = "مبلغ", Width = 110, Format = "N0", Total = true }
            }
        };

        var data = new PrintDataModel
        {
            CompanyName = "ترازین",
            Title = "گزارش چکها",
            RangeText = "بازه تست",
            QrEnabled = false
        };
        data.MetaFields.Add(new PrintMetaField { Label = "بازه", Value = "1405/06/01", Bold = true });
        data.MetaFields.Add(new PrintMetaField { Label = "وضعیت", Value = "در انتظار" });
        data.Rows.Add(new PrintRow { ["ChequeNumber"] = "CHQ-1", ["DueDate"] = "1405/06/02", ["Amount"] = 500000000m });
        data.Rows.Add(new PrintRow { ["ChequeNumber"] = "CHQ-2", ["DueDate"] = "1405/06/03", ["Amount"] = 20000000m });

        var bytes = svc.BuildTemplatePdf(tpl, data);
        Assert.True(bytes.Length > 100, $"PDF bytes too small: {bytes.Length}");
    }

    [Fact]
    public void BuildTemplatePdf_dumps_for_inspection()
    {
        var svc = new PdfReportService();
        var tpl = new PrintTemplateDef
        {
            Id = "treasury.cheques",
            Name = "چکها",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            MarginMm = 10,
            FontSizePt = 8.5f,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            ReportTitle = "گزارش چک‌ها",
            MetaFields = new System.Collections.Generic.List<PrintMetaField>
            {
                new() { Label = "بازه", Bold = true },
                new() { Label = "وضعیت", Bold = false }
            },
            Columns = new System.Collections.Generic.List<PrintColumnDef>
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

        var data = new PrintDataModel
        {
            CompanyName = "ترازین — سامانه یکپارچه مدیریت کسب‌وکار",
            Title = "گزارش چک‌های در جریان و سررسیدشده",
            RangeText = "تعداد 9 چک — تهیه‌شده در 1405/06/07",
            QrEnabled = false
        };
        data.MetaFields.Add(new PrintMetaField { Label = "چک‌های باز", Value = "9", Bold = true });
        data.MetaFields.Add(new PrintMetaField { Label = "سررسیدشده", Value = "3", Bold = true });
        data.MetaFields.Add(new PrintMetaField { Label = "سررسید نزدیک", Value = "1", Bold = true });
        data.Rows.Add(new PrintRow
        {
            ["ChequeNumber"] = "CHQ-50001", ["BankName"] = "بانک صادرات ایران", ["Direction"] = "دریافتی",
            ["StatusTitle"] = "در انتظار", ["DueDate"] = "1405/06/02", ["AlertTitle"] = "سررسیدشده",
            ["Amount"] = 500000000m, ["SourceReference"] = "دستی"
        });
        data.Rows.Add(new PrintRow
        {
            ["ChequeNumber"] = "CHQ-10001", ["BankName"] = "بانک ملی ایران", ["Direction"] = "دریافتی",
            ["StatusTitle"] = "در انتظار", ["DueDate"] = "1405/06/24", ["AlertTitle"] = "در مهلت",
            ["Amount"] = 500000000m, ["SourceReference"] = "دستی"
        });
        data.FooterFields.Add(new PrintMetaField { Label = "جمع مبلغ", Value = "۱٬۰۰۰٬۰۰۰٬۰۰۰", Bold = true });

        var bytes = svc.BuildTemplatePdf(tpl, data);
        var dir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "tarazin-pdf");
        System.IO.Directory.CreateDirectory(dir);
        var path = System.IO.Path.Combine(dir, "cheque-alignment-test.pdf");
        System.IO.File.WriteAllBytes(path, bytes);
        Assert.True(bytes.Length > 500);
    }
}