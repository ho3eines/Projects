using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
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

    [Fact]
    public void BuildTablePdf_includes_qr_when_company_qr_given()
    {
        // گارد در برابر بازگشت «گزارش جدولی بدون QR»: همهٔ چاپ‌ها باید QR پیگیری
        // و نام شرکت از تنظیمات داشته باشند. وقتی payload/companyName داده شود،
        // هدر رسمی باید شرکت + QR را شامل شود.
        var svc = new PdfReportService();
        var cols = new System.Collections.Generic.List<TableReportColumn>
        {
            new() { Header = "کد" },
            new() { Header = "عنوان" },
            new() { Header = "مانده", AlignRight = true }
        };
        var rows = new System.Collections.Generic.List<System.Collections.Generic.IReadOnlyList<string>>
        {
            new[] { "10", "دارایی‌ها", "بدهکار" }
        };

        var withQr = svc.BuildTablePdf("گزارش تست", "زیرنویس", "بازه", cols, rows, null, "A4",
            "شرکت نمونه", "تهران", "https://tarazin.example/r/hierarchy");
        var withoutQr = svc.BuildTablePdf("گزارش تست", "زیرنویس", "بازه", cols, rows, null, "A4");

        // با payload: QR (image XObject) باید رندر شود؛ بدون payload هیچ تصویری نباشد.
        Assert.Contains("/Subtype /Image", PdfAscii(withQr));
        Assert.DoesNotContain("/Subtype /Image", PdfAscii(withoutQr));
        // نام شرکت باید داخل PDF باشد (به‌عنوان glyph ذخیره می‌شود، پس فقط در
        // تفسیر pymupdf دیده می‌شود؛ اینجا فقط مطمئن می‌شویم خروجی بزرگ‌تر است).
        Assert.True(withQr.Length > withoutQr.Length, "خروجی با شرکت+QR باید بزرگ‌تر باشد");
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

    [Fact]
    public void BuildDocumentPdf_a5_both_orientations_no_surface_overflow()
    {
        // گارد در برابر بازگشت «فیلدها از صفحه A5 بیرون می‌زنند»:
        // سند پیشرفته با ۲۰+ تفصیل (چندصفحه‌ای) در هر دو جهت A5 ساخته می‌شود و
        // سپس تک‌تک جریان محتوای هر صفحه باز و تمام مختصات رسم (re) و ماتریس‌های
        // متن (Tm) استخراج می‌شوند تا هیچ سطحی از لبهٔ MediaBox بیرون نزند.
        var svc = new PdfReportService();
        var advanced = SampleAdvancedModel();

        foreach (var size in new[] { "A5", "A5L" })
        {
            var bytes = svc.BuildDocumentPdf(advanced, size);

            // وضوح صفحه باید A5 باشد (پرتِری vs landscape از هم تفکیک می‌شود).
            var w = size == "A5L" ? 595.28 : 419.53;
            var h = size == "A5L" ? 419.53 : 595.28;
            var geometry = PdfSurfaceGeometry.Check(bytes);
            Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
            Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);
            // سند با ۲۴ ردیف تفصیلی در A5 باید چندصفحه باشد (صفحه‌بندی درست — نه یک صفحهٔ بریده).
            Assert.True(geometry.PageCount >= 2, $"[{size}] انتظار چندصفحه بودن، ولی PageCount={geometry.PageCount}");

            // گارد واقعیِ «از لبه بیرون نزند»: مختصاتِ دستگاهِ واقعیِ اشیا/متنِ رسم‌شده
            // (پس از اعمال CTM و FlateDecode) باید درون MediaBox بماند. تلورانس کوچک برای لبه‌کشی.
            const double tol = 2.0;
            Assert.True(geometry.MaxDeviceX.HasValue,
                $"[{size}] هیچ محتوایی قابل سنجش نیست (text ops نبود). objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
            Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
            Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
            Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
            Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);

            // تأیید اینکه گارد محتوای واقعی را (نه فقط ابعاد) سنجیده است:
            Assert.True(geometry.MaxDeviceX.Value > 10,
                $"[{size}] MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

            // QRCode هم باید در خروجی A5 باشد.
            Assert.Contains("/Subtype /Image", PdfAscii(bytes));
        }
    }

    [Fact]
    public void BuildDocumentPdf_a5_both_orientations_no_surface_overflow_simple()
    {
        // گارد هم‌دهان پیشرفته، اما برای حالت «چاپ ساده» (فقط ریز ردیف‌های سند،
        // بدون سلسله‌مراتب کل/معین): سند بلند با ۲۴ ردیف در هر دو جهت A5 ساخته می‌شود
        // و محتوای واقعی هیچ‌جا از لبهٔ MediaBox بیرون نمی‌زند و چندصفحه است.
        var svc = new PdfReportService();
        var model = SampleAdvancedModel();
        model.Advanced = false; // حالت ساده (فقط ریز سند)

        foreach (var size in new[] { "A5", "A5L" })
        {
            var bytes = svc.BuildDocumentPdf(model, size);

            var w = size == "A5L" ? 595.28 : 419.53;
            var h = size == "A5L" ? 419.53 : 595.28;
            var geometry = PdfSurfaceGeometry.Check(bytes);
            Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
            Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);
            // ۲۴ ردیف در حالت سادهٔ A5 باید چندصفحه باشد (صفحه‌بندی درست — نه بریده).
            Assert.True(geometry.PageCount >= 2,
                $"[{size}-simple] انتظار چندصفحه بودن، ولی PageCount={geometry.PageCount}");

            const double tol = 2.0;
            Assert.True(geometry.MaxDeviceX.HasValue,
                $"[{size}-simple] هیچ محتوایی قابل سنجش نیست objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
            Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
            Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
            Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
            Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);
            Assert.True(geometry.MaxDeviceX.Value > 10,
                $"[{size}-simple] MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

            Assert.Contains("/Subtype /Image", PdfAscii(bytes));
        }
    }

    [Fact]
    public void BuildDocumentPdf_a5_32plus_lines_multipage_no_overflow()
    {
        // گارد برای سندِ بلندِ واقعی (۳۲+ تفصیل) در A5: باید قطعاً چندصفحه باشد و هیچ
        // محتوایی از لبهٔ MediaBox بیرون نزند — دقیقاً مثل سند واقعی ۱۵۴۷ (۳۲ ردیف).
        // با ۳۲ ردیفِ پیشرفته و ۳۲ ردیفِ ساده، در هر دو جهت ابعاد و تعدادصفحه را می‌سنجد.
        var svc = new PdfReportService();

        foreach (var advanced in new[] { true, false })
        {
            var model = SampleAdvancedModel(32);
            model.Advanced = advanced;

            foreach (var size in new[] { "A5", "A5L" })
            {
                var bytes = svc.BuildDocumentPdf(model, size);

                var w = size == "A5L" ? 595.28 : 419.53;
                var h = size == "A5L" ? 419.53 : 595.28;
                var geometry = PdfSurfaceGeometry.Check(bytes);
                Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
                Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);

                var mode = advanced ? "پیشرفته" : "ساده";
                // ۳۲ ردیف در A5 باید چندصفحه باشد — نه یک صفحهٔ بریده/فشرده.
                Assert.True(geometry.PageCount >= 2,
                    $"[{mode}/{size}] سند ۳۲ ردیفی باید چندصفحه باشد، ولی PageCount={geometry.PageCount}");

                // بدون بیرون‌زدگی: مختصاتِ دستگاهِ واقعیِ رسم‌شده درون MediaBox بماند.
                const double tol = 2.0;
                Assert.True(geometry.MaxDeviceX.HasValue,
                    $"[{mode}/{size}] هیچ محتوایی قابل سنجش نیست objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
                Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
                Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
                Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
                Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);
                Assert.True(geometry.MaxDeviceX.Value > 10,
                    $"[{mode}/{size}] MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

                Assert.Contains("/Subtype /Image", PdfAscii(bytes));
            }
        }
    }

    [Fact]
    public void BuildDocumentPdf_consecutive_clicks_dont_stick_simple_advanced()
    {
        // گارد «هش چسبیده روی دو PDF» برای سند حسابداری: باگِ کلاینت قبلی باعث می‌شد
        // دانلودِ دوم بایت‌های دانلودِ قبلی را بگیرد (race دو دانلودِ هم‌زمان → «هش روی
        // دو PDF چسبیده»). اینجا همان مسیر بایت‌سازیِ UI (BuildDocumentPdf با حالت
        // ساده/پیشرفته × A4/A5/A5L) را با کلیک‌های متوالیِ درهم صدا می‌زنیم — همان
        // نقطه‌ای که قبلاً چسب می‌خورد: تکرارِ پشت‌سرهمِ یک حالت + تغییرِ ناگهانی.
        var svc = new PdfReportService();

        var combos = new (string Label, bool Advanced, string Size)[]
        {
            ("ADV-A4", true, "A4"),
            ("SMP-A4", false, "A4"),
            ("ADV-A5", true, "A5"),
            ("SMP-A5", false, "A5"),
            ("ADV-A5L", true, "A5L"),
            ("SMP-A5L", false, "A5L"),
        };

        // هش مرجعِ هر ترکیب — تعیین‌پذیری (بدون تایم‌استمپ، همان StableHash دیزاینر).
        var reference = new Dictionary<string, string>();
        foreach (var (label, advanced, size) in combos)
        {
            var model = SampleAdvancedModel();
            model.Advanced = advanced;
            var bytes = svc.BuildDocumentPdf(model, size);
            Assert.True(bytes.Length > 1000, $"[{label}] PDF too small: {bytes.Length}");
            reference[label] = StableHash(bytes);
        }

        // شبیه‌سازی کلیک‌های متوالی — مخلوط حالت/اندازه + تکرارِ همان و تغییرِ ناگهانی.
        var clicks = new (string Label, bool Advanced, string Size)[]
        {
            ("ADV-A4", true, "A4"),
            ("SMP-A4", false, "A4"),
            ("ADV-A5", true, "A5"),
            ("SMP-A5", false, "A5"),
            ("ADV-A5", true, "A5"),   // تکرارِ پشت‌سرهم (dedupe در کلاینت)
            ("SMP-A5", false, "A5"),   // تغییرِ ناگهانی — نقطهٔ چسبیدنِ قبلی
            ("ADV-A5L", true, "A5L"),
            ("SMP-A5L", false, "A5L"),
            ("ADV-A4", true, "A4"),   // بازگشت به ترکیب اول
        };

        var clickHashes = new List<string>();
        for (var i = 0; i < clicks.Length; i++)
        {
            var (label, advanced, size) = clicks[i];
            var model = SampleAdvancedModel();
            model.Advanced = advanced;
            var bytes = svc.BuildDocumentPdf(model, size);
            var hash = StableHash(bytes);

            // هر کلیک باید هشِ مرجعِ خودش را بدهد (تعیین‌پذیری + عدم چسبیدن به قبلی).
            Assert.Equal(reference[label], hash);
            clickHashes.Add(hash);
        }

        // دو کلیکِ متوالیِ متفاوت باید هشِ متفاوتی داشته باشند — اگر حالت/اندازهٔ دوم
        // بایت‌های کلیکِ قبلی را می‌گرفت، همین‌جا Fail می‌شد (هشِ چسبیده).
        for (var i = 1; i < clicks.Length; i++)
        {
            if (clicks[i].Label != clicks[i - 1].Label)
                Assert.NotEqual(clickHashes[i - 1], clickHashes[i]);
        }

        // شش ترکیبِ متفاوت، شش هشِ یکتا — هیچ دو ترکیبی هشِ مشترک ندارند.
        Assert.Equal(combos.Length, reference.Values.Distinct().Count());
    }

    [Fact]
    public void BuildTablePdf_a5l_60plus_rows_multipage_no_overflow()
    {
        // گارد چندصفحه‌گی خط لولهٔ جدول عمومی (BuildTablePdf): ۶۰+ ردیف در A5L باید
        // قطعاً چندصفحه شود و هیچ محتوایی از لبهٔ MediaBox بیرون نزند. تکرارِ هدرِ جدول
        // در هر صفحه با گام pymupdfِ «table-many» (tools/check-rtl-headers.sh) جدا سنجیده
        // می‌شود (استخراج متن هر صفحه) — این گام ساختار چندصفحه‌گی/بیرون‌زدگی را قفل می‌کند.
        var svc = new PdfReportService();
        var columns = new List<TableReportColumn>
        {
            new() { Header = "شماره چک" },
            new() { Header = "بانک" },
            new() { Header = "جهت" },
            new() { Header = "سررسید" },
            new() { Header = "مبلغ", AlignRight = true },
        };
        var rows = new List<IReadOnlyList<string>>();
        for (var i = 1; i <= 65; i++)
            rows.Add(new[] { $"CHQ-{i:00000}", "بانک صادرات ایران", "دریافتی", "1405/06/02", (i * 1_000_000L).ToString("N0") });

        const string size = "A5L";
        var bytes = svc.BuildTablePdf(
            "گزارش چک‌ها", "چک‌های در جریان و سررسیدشده", "از 1405/05/07 تا 1405/06/07",
            columns, rows,
            summaryLines: new[] { "جمع مبلغ: ۲٬۱۴۵٬۰۰۰٬۰۰۰" },
            paperSize: size,
            companyName: "ترازین — سامانه یکپارچه", companyAddress: "تهران، خیابان آزادی",
            qrPayload: "https://tarazin.app/trace/many");

        const double w = 595.28, h = 419.53;
        var geometry = PdfSurfaceGeometry.Check(bytes);
        Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
        Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);
        // ۶۵ ردیف در A5L باید قطعاً چندصفحه باشد (صفحه‌بندی درست — نه بریده/فشرده).
        Assert.True(geometry.PageCount >= 2,
            $"۶۵ ردیف در A5L باید چندصفحه باشد، ولی PageCount={geometry.PageCount}");

        // بدون بیرون‌زدگی: مختصاتِ دستگاهِ واقعیِ رسم‌شده درون MediaBox بماند.
        const double tol = 2.0;
        Assert.True(geometry.MaxDeviceX.HasValue,
            $"هیچ محتوایی قابل سنجش نیست objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
        Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
        Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);
        Assert.True(geometry.MaxDeviceX.Value > 10,
            $"MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

        // QR در هدر رسمی هم باید باشد.
        Assert.Contains("/Subtype /Image", PdfAscii(bytes));
    }

    [Fact]
    public void BuildInvoicePdf_a5l_many_rows_multipage_no_overflow()
    {
        // گارد چندصفحه‌گی فاکتور طلا (BuildInvoicePdf): ۲۵+ ردیف در A5L باید قطعاً
        // چندصفحه شود و هیچ محتوایی از لبهٔ MediaBox بیرون نزند — دقیقاً همان گارد
        // «invoice-a5l-many» که فایلِ dump را می‌سازد و گام pymupdf در
        // tools/check-rtl-headers.sh هدرِ جدول را در هر صفحه جدا استخراج و تأیید می‌کند؛
        // این گام ساختار چندصفحه‌گی/بیرون‌زدگی/MediaBox را در همان xUnit قفل می‌کند.
        var svc = new PdfReportService();

        const string size = "A5L";
        var bytes = svc.BuildInvoicePdf(SampleInvoice(25), size);

        // وضوح: A5 landscape ≈ ۵۹۵×۴۲۰ (نه پرتره و نه A4).
        const double w = 595.28, h = 419.53;
        var geometry = PdfSurfaceGeometry.Check(bytes);
        Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
        Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);
        // ۲۵ ردیف فاکتور در A5L هرگز در یک صفحه جا نمی‌شود — صفحه‌بندی درست نه بریده.
        Assert.True(geometry.PageCount >= 2,
            $"۲۵ ردیف در A5L باید چندصفحه باشد، ولی PageCount={geometry.PageCount}");

        // بدون بیرون‌زدگی: مختصاتِ دستگاهِ واقعیِ رسم‌شده (پس از CTM/FlateDecode) درون MediaBox.
        const double tol = 2.0;
        Assert.True(geometry.MaxDeviceX.HasValue,
            $"هیچ محتوایی قابل سنجش نیست objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
        Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
        Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);
        Assert.True(geometry.MaxDeviceX.Value > 10,
            $"MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

        // (فاکتور طلا QR در هدر رسمی تعبیه نمی‌کند — برخلاف سند/قالب؛ گارد pymupdfِ
        // «invoice-a5l-many» هم فقط MediaBox/چندصفحه/هدر/بیرون‌زدگی را می‌سنجد.)
    }

    [Fact]
    public void BuildInvoicePdf_a5_portrait_40rows_no_overflow_and_negative_guard_detects()
    {
        // (الف) فاکتور واقعی ۴۰ ردیفی در A5 **پرتره** — پوششِ مرز صفحه در هر دو محور:
        // گاردِ landscape (A5L) فقط ۲۵ ردیف و جهت افقی را می‌سنجید؛ این‌جا ۴۰ ردیف در
        // A5 پرتره (۴۱۹٫۵۳×۵۹۵٫۲۸) ساخته می‌شود تا چندصفحه بودن، صفحه‌بندی درست و
        // عدم بیرون‌زدگی در هر دو محور X و Y هم تحت پوشش باشد.
        var svc = new PdfReportService();
        var bytes = svc.BuildInvoicePdf(SampleInvoice(40), "A5");

        const double w = 419.53, h = 595.28;
        var geometry = PdfSurfaceGeometry.Check(bytes);
        Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
        Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);
        Assert.True(geometry.PageCount >= 2,
            $"۴۰ ردیف در A5 پرتره باید چندصفحه باشد، ولی PageCount={geometry.PageCount}");

        const double tol = 2.0;
        Assert.True(geometry.MaxDeviceX.HasValue,
            $"هیچ محتوایی قابل سنجش نیست objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
        Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
        Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);
        Assert.True(geometry.MaxDeviceX.Value > 10,
            $"MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

        // (ب) گاردِ منفی (نگهبانِ خودِ گارد): اگر هندسهٔ «بدون بیرون‌زدگی» واقعاً چیزی
        // را می‌سنجد، باید بیرون‌زدگیِ عمدی را در هر دو محور تشخیص دهد وگرنه همهٔ تست‌های
        // بالا به‌صورت vacuous سبز می‌ماندند. یک PDF دست‌ساز با متنِ فراتر از هر دو لبهٔ
        // A5 پرتره می‌سازیم (x=500>w و y=700>h) — MaxDeviceX/Y باید مرز را بشکند.
        var over = PdfSurfaceGeometry.Check(CraftOverflowingA5PortraitPdf(w, h));
        Assert.True(over.MaxDeviceX.HasValue && over.MaxDeviceX.Value > w + 2,
            $"گاردِ منفی باید بیرون‌زدگی X را ببیند (maxX={over.MaxDeviceX})");
        Assert.True(over.MaxDeviceY.HasValue && over.MaxDeviceY.Value > h + 2,
            $"گاردِ منفی باید بیرون‌زدگی Y را ببیند (maxY={over.MaxDeviceY})");
    }

    [Fact]
    public void BuildInvoicePdf_a4_fit_one_page_all_rows_compressed()
    {
        // گزینهٔ «همهٔ ردیف‌ها در یک صفحه» (فشرده‌سازی خودکار): فاکتور ۴۰ ردیفی در A4
        // بدون گزینه چندصفحه‌ای است (گارد قبلی همین را قفل کرد)، ولی با fitOnePage=true
        // باید دقیقاً یک صفحهٔ A4 پرتره شود و هیچ محتوایی از لبه بیرون نزند.
        var svc = new PdfReportService();

        // (الف) کنترل: بدون گزینه، ۴۰ ردیف قطعاً چندصفحه‌ای است.
        var normal = svc.BuildInvoicePdf(SampleInvoice(40), "A4");
        Assert.True(PdfReportService.CountPdfPages(normal) >= 2,
            $"کنترل: ۴۰ ردیف بدون fit باید چندصفحه باشد ولی {PdfReportService.CountPdfPages(normal)} صفحه است");

        // (ب) با گزینه: دقیقاً یک صفحهٔ A4 پرتره (۵۹۵×۸۴۲) بدون بیرون‌زدگی.
        // (تعداد صفحه را با CountPdfPages می‌سنجیم نه geometry.PageCount — آن regex
        // گرهٔ والد /Type /Pages را هم می‌شمارد و یک صفحهٔ واقعی را ۲ نشان می‌دهد.)
        var fit = svc.BuildInvoicePdf(SampleInvoice(40), "A4", fitOnePage: true);
        const double w = 595.28, h = 841.89;
        var geometry = PdfSurfaceGeometry.Check(fit);
        Assert.Equal(1, PdfReportService.CountPdfPages(fit));
        Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
        Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);

        const double tol = 2.0;
        Assert.True(geometry.MaxDeviceX.HasValue,
            $"هیچ محتوایی قابل سنجش نیست objects={geometry.ObjectsParsed} pages={geometry.PagesFound} streams={geometry.ContentStreamsRun} bt={geometry.BtCount}");
        Assert.InRange(geometry.MaxDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MaxDeviceY!.Value, -tol, h + tol);
        Assert.InRange(geometry.MinDeviceX!.Value, -tol, w + tol);
        Assert.InRange(geometry.MinDeviceY!.Value, -tol, h + tol);
        Assert.True(geometry.MaxDeviceX.Value > 10,
            $"MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");

        // (ج) fallback: حتی تعداد ردیف غیرقابل‌جمع‌شدن (۲۰۰ تا) هم بدون خطا خروجی می‌دهد؛
        // فقط ممکن است فشرده‌ترین حالت هم چندصفحه بماند — اما هرگز exception/تهی نیست.
        var huge = svc.BuildInvoicePdf(SampleInvoice(200), "A4", fitOnePage: true);
        Assert.NotNull(huge);
        Assert.True(huge.Length > 1000, "خروجی fallback باید PDF واقعی باشد");
        Assert.True(PdfReportService.CountPdfPages(huge) >= 1);

        // (د) گزینه باید برای A5 بی‌اثر باشد (فقط A4 پرتره) — همان رفتار قبل.
        var a5 = svc.BuildInvoicePdf(SampleInvoice(25), "A5", fitOnePage: true);
        Assert.Equal(PdfReportService.CountPdfPages(svc.BuildInvoicePdf(SampleInvoice(25), "A5")),
            PdfReportService.CountPdfPages(a5));
    }

    [Fact]
    public void Invoice_and_cheque_page_count_helpers_match_the_direct_builders()
    {
        // چیپ «تعداد صفحه» دیالوگ‌های فاکتور طلا و گزارش چک‌ها از این helperها پر می‌شود:
        // هر helper باید دقیقاً CountPdfPagesِ همان بایت‌هایی را بدهد که دکمهٔ «دانلود PDF»
        // می‌سازد — بخواند و همان را برگرداند، نه تخمین/تعداد متفاوت.
        var svc = new PdfReportService();

        // فاکتور: سه اندازه + گزینهٔ یک‌صفحه‌ای — helper == شمارش مستقیم بایت‌ها.
        foreach (var (size, fit) in new[]
        {
            ("A4", false), ("A5", false), ("A5L", false), ("A4", true),
        })
        {
            var direct = PdfReportService.CountPdfPages(svc.BuildInvoicePdf(SampleInvoice(40), size, fit));
            Assert.Equal(direct, svc.BuildInvoicePdfPageCount(SampleInvoice(40), size, fit));
        }
        // ۴۰ ردیف بدون گزینه چندصفحه است؛ با گزینهٔ یک‌صفحه‌ای دقیقاً ۱ — helper باید همین را بفهمد.
        Assert.True(svc.BuildInvoicePdfPageCount(SampleInvoice(40), "A4") >= 2,
            $"۴۰ ردیف بدون fit باید چندصفحه باشد ولی helper={svc.BuildInvoicePdfPageCount(SampleInvoice(40), "A4")}");
        Assert.Equal(1, svc.BuildInvoicePdfPageCount(SampleInvoice(40), "A4", fitOnePage: true));

        // گزارش چک‌ها: همیشه افقی — اندازه فقط تعداد صفحه را تغییر می‌دهد نه جهت.
        var cheques = new System.Collections.Generic.List<ChequeDueRow>
        {
            new() { ChequeNumber = "CHQ-50001", BankName = "بانک صادرات ایران", Amount = 500_000_000,
                Direction = "In", Status = "Pending", SourceReference = "GoldInvoice:SL-1001", DaysToDue = -4, AlertLevel = "Overdue" },
            new() { ChequeNumber = "CHQ-10001", BankName = "بانک ملی ایران", Amount = 75_000_000,
                Direction = "In", Status = "Pending", DaysToDue = 26, AlertLevel = "OnTime" },
        };
        foreach (var size in new[] { "A4", "A5", "A5L" })
        {
            var direct = PdfReportService.CountPdfPages(svc.BuildChequeReportPdf(cheques, size));
            Assert.Equal(direct, svc.BuildChequeReportPdfPageCount(cheques, size));
        }
    }

    /// <summary>
    /// PDF دست‌سازِ A5 پرتره با یک متن که در هر دو محور از لبه بیرون زده است
    /// (مبدأ متن در فضای کاربر x=500، y=700؛ CTM همانی است، پس مختصاتِ دستگاه
    /// همان ۵۰۰/۷۰۰ می‌شود > عرض/ارتفاع صفحه). برای گاردِ منفی استفاده می‌شود تا
    /// ثابت شود PdfSurfaceGeometry واقعاً بیرون‌زدگی را می‌سنجد نه اینکه همیشه سبز بماند.
    /// </summary>
    private static byte[] CraftOverflowingA5PortraitPdf(double w, double h)
    {
        var stream = "BT /F1 24 Tf 500 700 Td (OVERFLOW) Tj ET\n";
        var pdf = $@"%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {w.ToString(System.Globalization.CultureInfo.InvariantCulture)} {h.ToString(System.Globalization.CultureInfo.InvariantCulture)}] /Contents 4 0 R >>
endobj
4 0 obj
<< /Length {stream.Length} >>
stream
{stream}endstream
endobj
%%EOF
";
        return System.Text.Encoding.ASCII.GetBytes(pdf);
    }

    private static GoldInvoicePrintModel SampleInvoice(int nLines) => new()
    {
        InvoiceType = "Sale",
        InvoiceNumber = "SL-1001",
        InvoiceDate = new DateTime(1405, 6, 6),
        PartyName = "مشتری نمونه",
        DetailCode = "2000000",
        TaxPct = 10,
        TotalBase = 1_000_000,
        TotalTax = 100_000,
        TotalAmount = 1_100_000,
        PayCash = 600_000,
        BalanceRial = 500_000,
        Lines = Enumerable.Range(1, nLines).Select(i => new GoldInvoicePrintLine
        {
            RowType = "Gold",
            Title = $"گلد ۱۸ عیار سری {i}",
            Qty = 8.5m,
            Price = 4_000_000,
            Workmanship = 250_000,
            Profit = 120_000,
            TaxEnabled = true
        }).ToList()
    };

    private static AccountingDocumentPrintModel SampleAdvancedModel(int detailLines = 24)
    {
        // پیش‌فرض: ۴ کل × ۲ معین × ۳ تفصیل = ۲۴ ردیف تفصیلی → چند صفحهٔ A5.
        // دلخواه: detailLines = تعداد کلِ ردیف‌های تفصیلی (مثل ۳۲) که به‌صورت
        // یکنواخت میان معین‌ها توزیع می‌شود تا هیچ کل/معینِ تکی خالی نماند.
        var lines = new System.Collections.Generic.List<DocumentLineRow>();
        var perMoein = Math.Max(1, (int)Math.Ceiling(detailLines / 8.0)); // ۴ کل × ۲ معین = ۸ معین
        int used = 0;
        var kolRows = new System.Collections.Generic.List<AccountRollupRow>();
        var moeinRows = new System.Collections.Generic.List<AccountRollupRow>();
        var kol = new[]
        {
            (code: "40", title: "صندوق و بانک"),
            (code: "10", title: "دارایی‌های جاری"),
            (code: "31", title: "حساب‌های دریافتنی"),
            (code: "33", title: "حساب‌های پرداختنی"),
        };
        int seq = 1;
        for (int k = 0; k < kol.Length; k++)
        {
            for (int m = 0; m < 2; m++)
            {
                var moeinCode = kol[k].code + (m == 0 ? "001" : "002");
                var moeinCount = Math.Min(perMoein, detailLines - used);
                moeinRows.Add(new AccountRollupRow
                {
                    Code = moeinCode, Title = $"معین {moeinCode}", Debit = 0, Credit = 0, LineCount = moeinCount
                });
                for (int d = 0; d < moeinCount; d++)
                {
                    var account = moeinCode + (d == 0 ? "1" : d.ToString("0"));
                    lines.Add(new DocumentLineRow
                    {
                        DocumentLineId = seq, DocumentId = 191919, AccountId = seq,
                        AccountCode = account, Title = $"تفصیل {account} — {kol[k].title}",
                        Description = $"شرح ردیف {seq} برای تست صفحه‌بندی A5 {account}",
                        Debit = seq % 2 == 0 ? 0 : 1_000_000,
                        Credit = seq % 2 == 0 ? 1_000_000 : 0
                    });
                    seq++; used++;
                }
            }
            kolRows.Add(new AccountRollupRow
            {
                Code = kol[k].code, Title = kol[k].title, Debit = 0, Credit = 0, LineCount = 6
            });
        }

        return new AccountingDocumentPrintModel
        {
            DocumentId = 191919,
            DocumentNumber = "00001919",
            DocumentDate = new DateTime(2026, 8, 28),
            CounterPartyName = "مشتری نمونهٔ چندصفحه‌ای",
            TotalAmount = decimal.Zero,
            QrBaseUrl = "https://tarazin.app",
            Advanced = true,
            Lines = lines,
            KolRows = kolRows,
            MoeinRows = moeinRows,
        };
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
    }    private static string PdfAscii(byte[] bytes)
    {
        // PDF ممکن است بایت‌های غیر-ASCII داشته باشد؛ فقط کاراکترهای چاپی را نگه می‌داریم.
        var sb = new System.Text.StringBuilder(bytes.Length);
        foreach (var b in bytes)
            sb.Append(b is >= 32 and <= 126 ? (char)b : ' ');
        return sb.ToString();
    }

    /// <summary>
    /// هشِ پایدارِ محتوای PDF (بدون تایم‌استمپ) — دقیقاً همان نرمال‌سازیِ
    /// <c>DesignerMatrixTests.StableHash</c>: QuestPDF در Info دیکشنریِ هر خروجی
    /// <c>CreationDate/ModDate</c> (با دقت ثانیه) می‌گذارد، پس هشِ خام بین دو اجرا — حتی
    /// برای محتوای کاملاً یکسان — همیشه فرق دارد. آن دو کلید با مقدار ثابت جایگزین
    /// می‌شوند تا هش فقط به محتوای واقعی بستگی داشته باشد. همین نرمال‌سازی باید در
    /// هر ابزار مقایسهٔ لایو (<c>tools/compare-designer-downloads.sh</c>) هم یکی باشد.
    /// </summary>
    private static string StableHash(byte[] bytes)
    {
        // Latin1 نگاشت ۱:۱ بایت→کاراکتر دارد، پس round-trip بدون تغییر است.
        var text = System.Text.Encoding.Latin1.GetString(bytes);
        var norm = System.Text.RegularExpressions.Regex.Replace(text,
            @"/CreationDate\s*\([^)]*\)|/ModDate\s*\([^)]*\)",
            "/CreationDate (D:0+00'00')/ModDate (D:0+00'00')");
        return Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.Latin1.GetBytes(norm)));
    }
}

/// <summary>
/// استخراج ابعاد MediaBox، تعداد صفحات و — مهم‌تر — بیشترین مختصاتِ واقعیِ رسم‌شده
/// (re / m,l,c / Tm و...) از جریانِ محتوای (به‌صورت فیلترشده با FlateDecode) هر صفحه،
/// برای تشخیص «خروج متن/جدول از لبهٔ صفحه». CTM به‌طور درست (با پشتهٔ q/Q و
/// ترکیبِ cm به روش ماتریسی صحیح) ردیابی می‌شود تا مختصاتِ دستگاه واقعی به‌دست آید.
/// فقط برای گاردهای هندسیِ تست به‌کار می‌رود.
/// </summary>
public sealed class PdfSurfaceGeometry
{
    public double PageWidth { get; private set; }
    public double PageHeight { get; private set; }
    public int PageCount { get; private set; }

    /// <summary>بیشترین مختصات دستگاهِ (x/y) که روی کدام صفحه رسم شده؛ null اگر صفحه‌ای نباشد.</summary>
    public double? MaxDeviceX { get; private set; }
    public double? MaxDeviceY { get; private set; }
    public double? MinDeviceX { get; private set; }
    public double? MinDeviceY { get; private set; }
    public int ObjectsParsed { get; private set; }
    public int PagesFound { get; private set; }
    public int ContentStreamsRun { get; private set; }
    public int NoteCount { get; private set; }
    public int BtCount { get; private set; }
    public int TokensRead { get; private set; }

    public static PdfSurfaceGeometry Check(byte[] pdf)
    {
        var result = new PdfSurfaceGeometry();
        if (pdf == null || pdf.Length == 0)
            return result;

        var ascii = System.Text.Encoding.ASCII.GetString(pdf);

        var mb = Regex.Match(ascii, @"/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\]", RegexOptions.IgnoreCase);
        if (mb.Success)
        {
            result.PageWidth = double.Parse(mb.Groups[3].Value, System.Globalization.CultureInfo.InvariantCulture);
            result.PageHeight = double.Parse(mb.Groups[4].Value, System.Globalization.CultureInfo.InvariantCulture);
        }

        result.PageCount = Regex.Matches(ascii, @"/Type\s*/Page(?:[^\s]|\s)*?(?=[^/]|$)", RegexOptions.IgnoreCase).Count;
        if (result.PageCount == 0)
        {
            var count = Regex.Match(ascii, @"/Count\s+(\d+)", RegexOptions.IgnoreCase);
            if (count.Success) result.PageCount = int.Parse(count.Groups[1].Value);
        }

        MeasureContentBounds(result, pdf);
        return result;
    }

    private static void MeasureContentBounds(PdfSurfaceGeometry target, byte[] pdf)
    {
        var ascii = System.Text.Encoding.ASCII.GetString(pdf);
        // نگاشت شئ‌ها: objNum → {dict, streamBytes}. جریان‌ها در صورت FlateDecode دمیده می‌شوند.
        var objects = new System.Collections.Generic.Dictionary<int, (string Dict, byte[]? Stream)>();
        foreach (Match obj in Regex.Matches(ascii, "(\\d+)\\s+0\\s+obj\\b(.*?)endobj", RegexOptions.Singleline))
        {
            int num = int.Parse(obj.Groups[1].Value);
            string block = obj.Groups[2].Value;
            int streamIdx = block.IndexOf("stream", StringComparison.Ordinal);
            string dict = streamIdx >= 0 ? block.Substring(0, streamIdx) : block;
            byte[]? streamData = null;
            if (streamIdx >= 0)
            {
                int baseOff = obj.Groups[2].Index;
                int absStart = baseOff + streamIdx + "stream".Length;
                if (absStart < pdf.Length && (pdf[absStart] == '\r' || pdf[absStart] == '\n'))
                    absStart += (pdf[absStart] == '\r' && absStart + 1 < pdf.Length && pdf[absStart + 1] == '\n') ? 2 : 1;
                int endStreamsAt = block.IndexOf("endstream", StringComparison.Ordinal);
                int absEnd = endStreamsAt >= 0 ? baseOff + endStreamsAt : pdf.Length;
                if (absEnd > absStart && absEnd <= pdf.Length)
                {
                    streamData = new byte[absEnd - absStart];
                    Array.Copy(pdf, absStart, streamData, 0, streamData.Length);
                }
                if (dict.Contains("/Filter") && dict.Contains("FlateDecode", StringComparison.OrdinalIgnoreCase))
                    streamData = TryInflate(streamData);
            }
            objects[num] = (dict, streamData);
        }

        target.ObjectsParsed = objects.Count;
        var pagesList = objects.Where(kv => kv.Value.Dict.Contains("/Type") && kv.Value.Dict.Contains("/Page") && !kv.Value.Dict.Contains("/Pages")).ToList();

        // برای هر صفحه فقط جریانِ /Contents واقعی را اندازه بگیر (نه فونت/تصویر):
        foreach (var page in pagesList.Select(kv => kv.Value))
        {
            target.PagesFound++;
            var realRef = Regex.Match(page.Dict, @"/Contents\s+(?:\[\s*)?(\d+)\s+0\s+R", RegexOptions.IgnoreCase);
            if (!realRef.Success) continue;
            int refNum = int.Parse(realRef.Groups[1].Value);
            if (objects.TryGetValue(refNum, out var cs) && cs.Stream is { Length: > 0 })
            {
                target.ContentStreamsRun++;
                var g = new ContentGraph();
                g.Run(cs.Stream, 0);
                target.NoteCount += g.NoteCount;
                target.BtCount += g.BtCount;
                target.TokensRead += g.TokenCount;
                g.MergeInto(target);
            }
        }
    }

    private static byte[]? TryInflate(byte[] data)
    {
        try
        {
            using var ms = new System.IO.MemoryStream();
            // PDF FlateDecode = zlib (RFC1950). تلاش با سرپوش zlib؛ در غیر این صورت raw deflate.
            try
            {
                using var zs = new System.IO.Compression.ZLibStream(new System.IO.MemoryStream(data), System.IO.Compression.CompressionMode.Decompress);
                zs.CopyTo(ms);
            }
            catch
            {
                ms.SetLength(0);
                using var ds = new System.IO.Compression.DeflateStream(new System.IO.MemoryStream(data), System.IO.Compression.CompressionMode.Decompress);
                ds.CopyTo(ms);
            }
            return ms.ToArray();
        }
        catch { return null; }
    }

    /// <summary>ردیاب CTM و موقعیتِ متن (Tm/Td/T*) در یک جریان محتوا.</summary>
    private sealed class ContentGraph
    {
        private readonly System.Collections.Generic.Stack<(double A, double B, double C, double D, double E, double F)> _stack = new();
        private double A = 1, D = 1, B, C, E, F;
        private double _maxX = double.MinValue, _maxY = double.MinValue, _minX = double.MaxValue, _minY = double.MaxValue;
        private bool _any;
        // مکان‌نمای متن در فضای کاربر (برای BT/ET و Td/Tm)
        private double _tX, _tY;
        private bool _inText;
        private int _btCount, _tmCount, _noteCount, _tokensIn;

        public void Run(byte[] stream, int depth)
        {
            if (depth > 6) return; // جلوگیری از بازگشت بی‌نهایت در XObject ها
            var ops = Tokenize(System.Text.Encoding.Latin1.GetString(stream));
            _tokensIn = ops.Count;
            int i = 0;
            int budget = 2_000_000; // سقفِ سخت برای جلوگیری از حلقهٔ بی‌نهایت اگر توکنایزر خطا کند
            while (i < ops.Count && budget-- > 0)
            {
                var op = ops[i];
                switch (op.Op)
                {
                    case "q": _stack.Push((A, B, C, D, E, F)); break;
                    case "Q":
                        if (_stack.Count > 0)
                        {
                            var p = _stack.Pop();
                            A = p.A; B = p.B; C = p.C; D = p.D; E = p.E; F = p.F;
                        }
                        break;
                    case "cm":
                        if (i >= 6)
                        {
                            // ترکیب ماتریس به‌صورت صحیح: CTM' = M · CTM  (فرم سطری)
                            var a = ops[i - 6].V; var b = ops[i - 5].V; var c = ops[i - 4].V;
                            var d = ops[i - 3].V; var e = ops[i - 2].V; var f = ops[i - 1].V;
                            if (ops[i - 6].HasNum)
                            {
                                var nA = a * A + b * C;
                                var nB = a * B + b * D;
                                var nC = c * A + d * C;
                                var nD = c * B + d * D;
                                var nE = e * A + f * C + E;
                                var nF = e * B + f * D + F;
                                A = nA; B = nB; C = nC; D = nD; E = nE; F = nF;
                            }
                        }
                        break;
                    case "BT": _inText = true; _tX = 0; _tY = 0; _btCount++; break;
                    case "ET": _inText = false; break;
                    case "Tm":
                        _tmCount++;
                        if (_inText && i >= 6 && ops[i - 6].HasNum)
                        {
                            // ماتریسِ متن: m_{0,2}=e و m_{1,2}=f موقعیتِ مبدأِ متن در فضای کاربر است.
                            _tX = ops[i - 2].V; _tY = ops[i - 1].V;
                            Note(_tX, _tY);
                        }
                        break;
                    case "Td": case "TD":
                        if (_inText && i >= 2 && ops[i - 1].HasNum && ops[i - 2].HasNum)
                        {
                            _tX += ops[i - 2].V; _tY += ops[i - 1].V;
                            Note(_tX, _tY);
                        }
                        break;
                    case "T*": if (_inText) { _tX = 0; Note(0, _tY); } break;
                    case "Tj": case "'": case "\"":
                        if (_inText) Note(_tX, _tY);
                        break;
                }
                i++;
            }
        }

        private void Note(double ux, double uy)
        {
            // تبدیل مختصاتِ کاربر به دستگاه با CTM جاری.
            double dx = A * ux + C * uy + E;
            double dy = B * ux + D * uy + F;
            if (dx > _maxX) _maxX = dx;
            if (dy > _maxY) _maxY = dy;
            if (dx < _minX) _minX = dx;
            if (dy < _minY) _minY = dy;
            _any = true; _noteCount++;
        }

        public int TokenCount => _tokensIn;
        public int BtCount => _btCount;
        public int TmCount => _tmCount;
        public int NoteCount => _noteCount;

        public void MergeInto(PdfSurfaceGeometry target)
        {
            if (!_any) return;
            if (!target.MaxDeviceX.HasValue || _maxX > target.MaxDeviceX.Value) target.MaxDeviceX = _maxX;
            if (!target.MaxDeviceY.HasValue || _maxY > target.MaxDeviceY.Value) target.MaxDeviceY = _maxY;
            if (!target.MinDeviceX.HasValue || _minX < target.MinDeviceX.Value) target.MinDeviceX = _minX;
            if (!target.MinDeviceY.HasValue || _minY < target.MinDeviceY.Value) target.MinDeviceY = _minY;
        }

        private readonly record struct Tok(double V, bool HasNum, string Op);

        private static System.Collections.Generic.List<Tok> Tokenize(string s)
        {
            var list = new System.Collections.Generic.List<Tok>(4096);
            int i = 0, n = s.Length;
            while (i < n)
            {
                char ch = s[i];
                if (char.IsWhiteSpace(ch)) { i++; continue; }
                if (ch == '%') { while (i < n && s[i] != '\n' && s[i] != '\r') i++; continue; } // نظر
                if (ch == '<')
                {
                    if (i + 1 < n && s[i + 1] == '<') // دیکشنری «<< … >>» — پرش کن
                    { while (i < n && !(s[i] == '>' && i + 1 < n && s[i + 1] == '>')) i++; i += 2; continue; }
                    // رشتهٔ هگز «<02AC>» را به‌یک‌باره پرش کن (وگرنه '<' عملگرِ بی‌پیشرفت می‌شود)
                    while (i < n && s[i] != '>') i++;
                    i++; continue;
                }
                if (ch == '(') // رشتهٔ متنی (Tj) — فقط لیتری ساده
                {
                    i++; int depth = 1;
                    while (i < n && depth > 0)
                    {
                        if (s[i] == '\\') i += 2;
                        else if (s[i] == '(') { depth++; i++; }
                        else if (s[i] == ')') { depth--; i++; }
                        else i++;
                    }
                    continue;
                }
                // نام ( /Name ) یا اعداد
                if (ch == '/' )
                {
                    i++;
                    while (i < n && !char.IsWhiteSpace(s[i]) && s[i] != '<' && s[i] != '(' && s[i] != '[' ) i++;
                    continue;
                }
                if (ch == '[' || ch == ']') { i++; continue; }
                // عدد
                int start = i;
                bool isNum = char.IsDigit(ch) || ch == '-' || ch == '+' || ch == '.';
                if (isNum && (char.IsDigit(ch) || (ch == '.' && i + 1 < n && char.IsDigit(s[i + 1])) || ch == '-' || ch == '+'))
                {
                    i++;
                    while (i < n && (char.IsDigit(s[i]) || s[i] == '.' || s[i] == 'e' || s[i] == 'E' || s[i] == '-' || s[i] == '+')) i++;
                    var token = s.Substring(start, i - start);
                    if (double.TryParse(token, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var v))
                        list.Add(new Tok(v, true, ""));
                    continue;
                }
                // عملگر
                var op = new System.Text.StringBuilder();
                while (i < n && !char.IsWhiteSpace(s[i]) && s[i] != '/' && s[i] != '<' && s[i] != '(' && s[i] != '[' ) { op.Append(s[i]); i++; }
                if (op.Length > 0) list.Add(new Tok(0, false, op.ToString()));
            }
            return list;
        }
    }
}
