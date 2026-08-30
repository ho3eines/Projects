using System;
using System.Linq;
using System.Text.RegularExpressions;
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

    [Fact]
    public void BuildHtml_column_widths_are_percentages_summing_to_100()
    {
        var tpl = new PrintTemplateDef
        {
            Id = "test.percentages",
            Name = "تست درصدها",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            FontSizePt = 8.5f,
            ShowCompanyHeader = false,
            ShowPageFooter = false,
            ShowReportFooter = false,
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "A", Title = "ستونA", Width = 90 },
                new() { Key = "B", Title = "ستونB", Width = 90 },
                new() { Key = "C", Title = "ستونC", Width = 70 },
                new() { Key = "D", Title = "ستونD", Width = 110 },
                new() { Key = "E", Title = "ستونE", Width = 130 }
            }
        };
        var data = new PrintDataModel
        {
            CompanyName = "تست",
            Title = "تست درصدها"
        };
        data.Rows.Add(new PrintRow { ["A"] = "x", ["B"] = "y", ["C"] = "z", ["D"] = "w", ["E"] = "v" });

        var html = PrintSheetRenderer.BuildHtml(tpl, data);

        // استخراج عرض‌های درصدی از thها
        var widthPattern = "width:([\\d.]+)%";
        var pctMatches = Regex.Matches(html, widthPattern);
        Assert.Equal(tpl.Columns.Count, pctMatches.Count);

        double sum = 0;
        var widths = new[] { 90, 90, 70, 110, 130 }; // مجموع = 490
        var totalW = widths.Sum(w => Math.Max(w, 20));
        for (int i = 0; i < tpl.Columns.Count; i++)
        {
            double expectedPct = Math.Max(widths[i], 20) * 100.0 / totalW;
            double actualPct = double.Parse(pctMatches[i].Groups[1].Value);
            Assert.InRange(actualPct, expectedPct - 0.2, expectedPct + 0.2);
            sum += actualPct;
        }
        // جمع درصدها باید تقریباً 100% باشد (خطای گرد کردن)
        Assert.InRange(sum, 99.5, 100.5);
    }

    [Fact]
    public void BuildHtml_small_width_clamped_to_20()
    {
        var tpl = new PrintTemplateDef
        {
            Id = "test.clamp",
            Name = "تست clamp",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "A", Title = "کوچک", Width = 5 },   // باید به 20 clamp شود
                new() { Key = "B", Title = "بزرگ", Width = 100 }
            }
        };
        var data = new PrintDataModel
        {
            CompanyName = "تست",
            Title = "تست clamp"
        };
        data.Rows.Add(new PrintRow { ["A"] = "x", ["B"] = "y" });

        var html = PrintSheetRenderer.BuildHtml(tpl, data);
        var widthPattern = "width:([\\d.]+)%";
        var pctMatches = Regex.Matches(html, widthPattern);
        Assert.Equal(2, pctMatches.Count);

        // totalW = Max(5,20) + Max(100,20) = 20 + 100 = 120
        double pctA = double.Parse(pctMatches[0].Groups[1].Value);
        double pctB = double.Parse(pctMatches[1].Groups[1].Value);
        Assert.InRange(pctA, 16.0, 17.5);   // 20/120 = 16.67%
        Assert.InRange(pctB, 82.5, 84.0);    // 100/120 = 83.33%
        Assert.InRange(pctA + pctB, 99.5, 100.5);
    }

    [Fact]
    public void BuildTemplatePdf_uses_relative_not_fixed_column_widths()
    {
        // گارد در برابر برگشت به عرض پیکسلی ثابت: جدول قالب در PDF باید از وزن نسبی
        // (RelativeColumn + Math.Max(col.Width, 20)) استفاده کند تا با درصدهای HTML هم‌راستا بماند.
        // از AppContext.BaseDirectory (Tarazin.Tests/bin/Debug/net8.0/) به سمت ریشه صعود می‌کنیم
        // تا به پوشهٔ حاوی Tarazin.Ui برسیم — مستقل از عمق مسیر بیلد.
        var dir = new System.IO.DirectoryInfo(AppContext.BaseDirectory);
        var root = (System.IO.DirectoryInfo?)null;
        for (var d = dir; d is not null; d = d.Parent)
        {
            if (System.IO.Directory.Exists(System.IO.Path.Combine(d.FullName, "Tarazin.Ui", "Services")))
            {
                root = d;
                break;
            }
        }
        Assert.True(root is not null, "پوشهٔ ریشه (شامل Tarazin.Ui) از مسیر بیلد پیدا نشد");
        var candidate = System.IO.Path.Combine(root!.FullName, "Tarazin.Ui", "Services", "PdfReportService.cs");
        Assert.True(System.IO.File.Exists(candidate), $"PdfReportService.cs not found at {candidate}");
        var source = System.IO.File.ReadAllText(candidate);

        // ۱) متد جدول قالب باید از RelativeColumn استفاده کند
        var methodStart = source.IndexOf("private static void BuildTemplateTable", StringComparison.Ordinal);
        Assert.True(methodStart >= 0, "BuildTemplateTable method not found in source");
        var methodEnd = source.IndexOf("private static void", methodStart + 10, StringComparison.Ordinal);
        var method = methodEnd > methodStart
            ? source.Substring(methodStart, methodEnd - methodStart)
            : source.Substring(methodStart);

        Assert.Contains("RelativeColumn(Math.Max(col.Width, 20))", method);
        Assert.DoesNotContain("ConstantColumn", method);
        Assert.DoesNotContain("RelativeColumn(1)", method); // وزن همهٔ ستون‌ها یکسان نباشد

        // ۲) هیچ جای PdfReportService جدول قالب با عرض پیکسلی ثابت نسازد
        //    (ConstantColumn فقط برای ستون «ردیف» فاکتور طلافروشی مجاز است)
        var constantCols = System.Text.RegularExpressions.Regex.Matches(source, @"ConstantColumn\(");
        Assert.True(constantCols.Count <= 1, $"Unexpected ConstantColumn usages: {constantCols.Count}");
        if (constantCols.Count == 1)
        {
            // متدِ شامل ConstantColumn را از روی آخرین «private static void» قبل از آن می‌یابیم
            var idx = constantCols[0].Index;
            var methodHeader = source.LastIndexOf("private static void", idx, System.StringComparison.Ordinal);
            Assert.True(methodHeader >= 0, "no method header before ConstantColumn");
            var methodNameStart = methodHeader + "private static void".Length;
            var methodNameEnd = source.IndexOf('(', methodNameStart);
            var methodName = source.Substring(methodNameStart, methodNameEnd - methodNameStart).Trim();
            Assert.Equal("BuildInvoiceLines", methodName); // تنها مورد مجاز: جدول فاکتور
        }
    }

    [Fact]
    public void BuildHtml_qr_renders_independent_of_company_header()
    {
        // گارد در برابر باگ «QR فقط با هدر شرکت رندر می‌شد»:
        // وقتی هدر شرکت خاموش است، QR باید به‌صورت مستقل (tpl-standalone-qr) ظاهر شود.
        var tpl = new PrintTemplateDef
        {
            Id = "test.qr",
            Name = "تست QR",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            ShowCompanyHeader = false,
            QrEnabled = true,
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "X", Title = "ستون", Width = 100 }
            }
        };
        var data = new PrintDataModel
        {
            CompanyName = "تست",
            Title = "تست QR",
            QrEnabled = true,
            QrPayload = "tarazin:tpl:test.qr"
        };
        data.Rows.Add(new PrintRow { ["X"] = "value" });

        var html = PrintSheetRenderer.BuildHtml(tpl, data);

        // QR نباید به هدر شرکت وابسته باشد
        Assert.DoesNotContain("tpl-company-header", html);
        Assert.Contains("tpl-standalone-qr", html);
        Assert.Contains("qr-fill", html);
        Assert.Contains("data-payload=\"tarazin:tpl:test.qr\"", html);
    }

    [Fact]
    public void BuildHtml_qr_hidden_when_disabled()
    {
        var tpl = new PrintTemplateDef
        {
            Id = "test.qroff",
            Name = "تست QR خاموش",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            ShowCompanyHeader = true,
            QrEnabled = false,
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "X", Title = "ستون", Width = 100 }
            }
        };
        var data = new PrintDataModel
        {
            CompanyName = "تست",
            Title = "تست QR خاموش",
            QrEnabled = false,
            QrPayload = "tarazin:tpl:test.qroff"
        };
        data.Rows.Add(new PrintRow { ["X"] = "value" });

        var html = PrintSheetRenderer.BuildHtml(tpl, data);

        Assert.DoesNotContain("qr-fill", html);
        Assert.DoesNotContain("tpl-standalone-qr", html);
    }

    [Fact]
    public void BuildHtml_qr_inside_company_header_when_header_on()
    {
        var tpl = new PrintTemplateDef
        {
            Id = "test.qrhdr",
            Name = "تست QR با هدر",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            ShowCompanyHeader = true,
            QrEnabled = true,
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "X", Title = "ستون", Width = 100 }
            }
        };
        var data = new PrintDataModel
        {
            CompanyName = "تست",
            Title = "تست QR با هدر",
            QrEnabled = true,
            QrPayload = "tarazin:tpl:test.qrhdr"
        };
        data.Rows.Add(new PrintRow { ["X"] = "value" });

        var html = PrintSheetRenderer.BuildHtml(tpl, data);

        // با هدر روشن: QR داخل هدر شرکت است (نه standalone)
        Assert.Contains("tpl-company-header", html);
        Assert.Contains("qr-fill", html);
        Assert.DoesNotContain("tpl-standalone-qr", html);
    }

    [Fact]
    public void BuildHtml_single_column_is_100_percent()
    {
        var tpl = new PrintTemplateDef
        {
            Id = "test.single",
            Name = "تست تک ستونی",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Landscape,
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "X", Title = "تنها ستون", Width = 50 }
            }
        };
        var data = new PrintDataModel
        {
            CompanyName = "تست",
            Title = "تست تک ستونی"
        };
        data.Rows.Add(new PrintRow { ["X"] = "value" });

        var html = PrintSheetRenderer.BuildHtml(tpl, data);
        var widthPattern = "width:([\\d.]+)%";
        var pctMatches = Regex.Matches(html, widthPattern);
        Assert.Single(pctMatches);
        double pct = double.Parse(pctMatches[0].Groups[1].Value);
        Assert.InRange(pct, 99.5, 100.5); // تنها ستون = 100%
    }

    // ─── QR مستقل در PDF (BuildTemplatePdf) — همان رفتار رندرر HTML ───

    [Fact]
    public void BuildTemplatePdf_renders_standalone_qr_when_header_off()
    {
        var svc = new PdfReportService();
        var tpl = SampleTemplate();
        tpl.ShowCompanyHeader = false;   // هدر شرکت خاموش
        tpl.QrEnabled = true;            // QR روشن → QR مستقل باید رندر شود

        var data = SampleData();
        data.QrEnabled = true;
        data.QrPayload = "tarazin:tpl:test-standalone";

        var bytes = svc.BuildTemplatePdf(tpl, data);
        Assert.True(bytes.Length > 200, $"PDF bytes too small: {bytes.Length}");
        // QuestPDF تصویر را به‌صورت XObject با /Subtype /Image در PDF جاسازی می‌کند.
        Assert.Contains("/Subtype /Image", PdfAscii(bytes));
    }

    [Fact]
    public void BuildTemplatePdf_renders_qr_inside_company_header_when_header_on()
    {
        var svc = new PdfReportService();
        var tpl = SampleTemplate();
        tpl.ShowCompanyHeader = true;    // هدر شرکت روشن → QR داخل هدر
        tpl.QrEnabled = true;

        var data = SampleData();
        data.QrEnabled = true;
        data.QrPayload = "tarazin:tpl:test-in-header";

        var bytes = svc.BuildTemplatePdf(tpl, data);
        Assert.Contains("/Subtype /Image", PdfAscii(bytes));
    }

    [Fact]
    public void BuildTemplatePdf_no_qr_image_when_qr_disabled()
    {
        var svc = new PdfReportService();
        var tpl = SampleTemplate();
        tpl.ShowCompanyHeader = true;
        tpl.QrEnabled = false;           // QR خاموش → هیچ تصویری در PDF نباشد

        var data = SampleData();
        data.QrEnabled = false;

        var bytes = svc.BuildTemplatePdf(tpl, data);
        Assert.DoesNotContain("/Subtype /Image", PdfAscii(bytes));
    }

    private static PrintTemplateDef SampleTemplate()
    {
        return new PrintTemplateDef
        {
            Id = "test.qr",
            Name = "تست QR",
            PaperSize = PrintPaperSize.A4,
            Orientation = PrintOrientation.Portrait,
            MarginMm = 10,
            FontSizePt = 9,
            ShowCompanyHeader = true,
            ShowPageFooter = true,
            ShowReportFooter = true,
            MetaFields = new System.Collections.Generic.List<PrintMetaField>
            {
                new() { Label = "شماره", Bold = true }
            },
            Columns = new System.Collections.Generic.List<PrintColumnDef>
            {
                new() { Key = "Code", Title = "کد", Width = 80 },
                new() { Key = "Amount", Title = "مبلغ", Width = 100, Format = "N0", Total = true }
            }
        };
    }

    [Fact]
    public void BuildDocumentPdf_simple_and_advanced_render_without_crash()
    {
        var svc = new PdfReportService();
        var lines = new System.Collections.Generic.List<DocumentLineRow>
        {
            new() { DocumentLineId = 1, DocumentId = 19, AccountCode = "400010000002", Title = "صندوق اصلی", Description = "دریافت از مشتری", Debit = 1000000, Credit = 0 },
            new() { DocumentLineId = 2, DocumentId = 19, AccountCode = "310010000005", Title = "مشتری نمونه", Description = "فروش نسیه", Debit = 0, Credit = 900000 },
            new() { DocumentLineId = 3, DocumentId = 19, AccountCode = "330020000001", Title = "مالیات بر ارزش افزوده", Description = "مالیات 10%", Debit = 0, Credit = 100000 },
        };
        var kolRows = new System.Collections.Generic.List<AccountRollupRow>
        {
            new() { Code = "31", Title = "حساب‌های دریافتنی", Debit = 0, Credit = 900000, LineCount = 1 },
            new() { Code = "33", Title = "حساب‌های پرداختنی", Debit = 0, Credit = 100000, LineCount = 1 },
            new() { Code = "40", Title = "صندوق و بانک", Debit = 1000000, Credit = 0, LineCount = 1 },
        };
        var moeinRows = new System.Collections.Generic.List<AccountRollupRow>
        {
            new() { Code = "31001", Title = "مشتریان", Debit = 0, Credit = 900000, LineCount = 1 },
            new() { Code = "33002", Title = "مالیات ارزش افزوده", Debit = 0, Credit = 100000, LineCount = 1 },
            new() { Code = "40001", Title = "صندوق", Debit = 1000000, Credit = 0, LineCount = 1 },
        };
        var model = new AccountingDocumentPrintModel
        {
            DocumentId = 19,
            DocumentNumber = "00000019",
            DocumentDate = new DateTime(2026, 8, 28),
            CounterPartyName = "مشتری نمونه",
            TotalAmount = 1000000,
            QrBaseUrl = "https://tarazin.app",
            Lines = lines,
            Advanced = true,
            KolRows = kolRows,
            MoeinRows = moeinRows,
        };

        var advanced = svc.BuildDocumentPdf(model, "A4");
        model.Advanced = false;
        var simple = svc.BuildDocumentPdf(model, "A4");

        Assert.True(advanced.Length > 1000, $"advanced too small {advanced.Length}");
        Assert.True(simple.Length > 1000, $"simple too small {simple.Length}");
        // چاپ پیشرفته باید از ساده متمایز باشد (ردیف‌های کل/معین/تفصیل بیشتر).
        Assert.NotEqual(advanced.Length, simple.Length);
        // هر دو باید QRCode داشته باشند (image XObject).
        Assert.Contains("/Subtype /Image", PdfAscii(advanced));
        Assert.Contains("/Subtype /Image", PdfAscii(simple));
    }

    private static PrintDataModel SampleData()
    {
        var data = new PrintDataModel
        {
            CompanyName = "ترازین",
            CompanyAddress = "تهران، خیابان آزادی",
            Title = "گزارش تست",
            RangeText = "بازه: 1405/06/01 تا 1405/06/31",
            QrEnabled = false
        };
        data.MetaFields.Add(new PrintMetaField { Label = "شماره", Value = "0001", Bold = true });
        data.Rows.Add(new PrintRow { ["Code"] = "A-1", ["Amount"] = 100000m });
        data.Rows.Add(new PrintRow { ["Code"] = "A-2", ["Amount"] = 200000m });
        return data;
    }

    private static string PdfAscii(byte[] bytes)
    {
        // PDF ممکن است بایت‌های غیر-ASCII داشته باشد؛ فقط کاراکترهای چاپی را نگه می‌داریم.
        var sb = new System.Text.StringBuilder(bytes.Length);
        foreach (var b in bytes)
            sb.Append(b is >= 32 and <= 126 ? (char)b : ' ');
        return sb.ToString();
    }
}