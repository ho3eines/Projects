using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using QuestPDF.Helpers;
using Tarazin.Models;
using Tarazin.Services;
using Tarazin.Tests; // PdfSurfaceGeometry (گارد بدون بیرون‌زدگی)
using Xunit;

namespace Tarazin.Tests.Services;

/// <summary>
/// تست‌های بازگشت‌پذیر روی خروجی/ساختار <see cref="PdfReportService"/>:
/// ابعاد و جهتٔ صفحه (MediaBox)، صفحه‌بندی فاکتورهای بلند، و راست‌به‌چپ بودن (RTL) محتوا.
///
/// گاردِ دو باگِ دیده‌شده:
///  - قبلاً <see cref="PdfReportService.BuildChequeReportPdf"/> خروجی A4 پرتره (595×842)
///    می‌ساخت چون `page.Size(pageSize)` به‌دلیل همنامی متغیر اعمال نمی‌شد → تست MediaBox
///    landscape را برای A4/A5 چک می‌کند.
///  - سلول‌های جدول اگر به‌صورت چپ‌چین رندر شوند خروجی فارسی به‌هم‌می‌ریزد → تست منبع
///    سلول‌های <c>HeaderCell</c>/<c>BodyCell</c> را باید راست‌چین (AlignRight) باشند.
///
/// یادداشت دربارهٔ تست RTL: راست‌چینی را از روی PDF نمی‌توان با مختصات x به‌طور مطمئن اثبات
/// کرد — QuestPDF جداول را روی تمام عرض صفحه می‌چیند و آخرین ستونِ حتی چپ‌چین هم به لبهٔ
/// راست می‌رسد. بنابراین راست‌چینی را در سطح منبع (وجود AlignRight روی سلول‌های مشترک) نگهبانی
/// می‌کنیم که مستقیماً همان رگرسیون «چپ‌چین شدن» را می‌گیرد.
/// </summary>
public class PdfReportServiceMediaBoxTests
{
    private static readonly PdfReportService Svc = new();

    // ─────────────────────────── فاکتور طلا ───────────────────────────

    [Theory]
    [InlineData("A4")]
    [InlineData("A5")]
    public void BuildInvoicePdf_uses_correct_portrait_size_for_paper(string paperSize)
    {
        var expected = paperSize == "A5" ? PageSizes.A5 : PageSizes.A4;
        var bytes = Svc.BuildInvoicePdf(SampleInvoice(4), paperSize);
        var box = Assert.Single(ParseMediaBoxes(bytes));

        Assert.True(box.Width < box.Height,
            $"فاکتور باید پرتره باشد ولی MediaBox={box} شده (باگ اندازهٔ صفحه برگشته).");
        Assert.InRange(box.Width, expected.Width - 2, expected.Width + 2);
        Assert.InRange(box.Height, expected.Height - 2, expected.Height + 2);
    }

    // ─────────────────────────── گزارش چک‌ها (landscape) ───────────────────────────

    [Theory]
    [InlineData("A4")]
    [InlineData("A5")]
    public void BuildChequeReportPdf_uses_correct_landscape_size_for_paper(string paperSize)
    {
        var expected = paperSize == "A5"
            ? PageSizes.A5.Landscape()
            : PageSizes.A4.Landscape();
        var bytes = Svc.BuildChequeReportPdf(SampleCheques(), paperSize);
        var box = Assert.Single(ParseMediaBoxes(bytes));

        Assert.True(box.Width > box.Height,
            $"گزارش چک‌ها باید landscape باشد ولی MediaBox={box} شده (باگ page.Size برگشته!).");
        Assert.InRange(box.Width, expected.Width - 2, expected.Width + 2);
        Assert.InRange(box.Height, expected.Height - 2, expected.Height + 2);
    }

    // ─────────────────── خط لولهٔ جداول عمومی (BuildTablePdf) ───────────────────

    [Fact]
    public void BuildTablePdf_wider_than_6_columns_uses_landscape()
    {
        var expected = PageSizes.A4.Landscape();
        var cols = Enumerable.Range(1, 8)
            .Select(i => new TableReportColumn { Header = $"ستون {i}" })
            .ToList();
        var rows = new List<IReadOnlyList<string>> { Enumerable.Range(1, 8).Select(i => i.ToString()).ToList() };

        var bytes = Svc.BuildTablePdf("گزارش عریض", "زیرنویس", "از تاریخ تا تاریخ", cols, rows);
        var box = Assert.Single(ParseMediaBoxes(bytes));

        Assert.True(box.Width > box.Height, "جدول با بیش از ۶ ستون باید landscape باشد.");
        Assert.InRange(box.Width, expected.Width - 2, expected.Width + 2);
        Assert.InRange(box.Height, expected.Height - 2, expected.Height + 2);
    }

    [Fact]
    public void BuildTablePdf_few_columns_uses_portrait()
    {
        var expected = PageSizes.A4;
        var cols = Enumerable.Range(1, 4)
            .Select(i => new TableReportColumn { Header = $"ستون {i}" })
            .ToList();
        var rows = new List<IReadOnlyList<string>> { Enumerable.Range(1, 4).Select(i => i.ToString()).ToList() };

        var bytes = Svc.BuildTablePdf("گزارش باریک", "زیرنویس", "از تاریخ تا تاریخ", cols, rows);
        var box = Assert.Single(ParseMediaBoxes(bytes));

        Assert.True(box.Width < box.Height, "جدول با ستون‌های کم باید پرتره باشد.");
        Assert.InRange(box.Width, expected.Width - 2, expected.Width + 2);
        Assert.InRange(box.Height, expected.Height - 2, expected.Height + 2);
    }

    [Fact]
    public void BuildTablePdf_a5l_landscape_media_box_and_no_overflow()
    {
        // گارد جداول عمومی: وقتی BuildTablePdf با «A5L» صدا زده می‌شود، MediaBox باید
        // دقیقاً ۵۹۵×۴۲۰ (A5 landscape ≈ 595.28×419.53) باشد و هیچ محتوای واقعی‌ای
        // از لبهٔ صفحه بیرون نزند — هم‌دهان با گاردهای قالب/سند/فاکتور.
        // ستون‌های کم (۴ تا) تا مطمئن شویم landscape از «A5L» آمده نه از قانون «>۶ ستون».
        var cols = Enumerable.Range(1, 4)
            .Select(i => new TableReportColumn { Header = $"ستون {i}" })
            .ToList();
        var rows = new List<IReadOnlyList<string>>
        {
            Enumerable.Range(1, 4).Select(i => i.ToString()).ToList(),
            Enumerable.Range(1, 4).Select(i => (i * 1_000_000).ToString("N0")).ToList()
        };

        foreach (var size in new[] { "A5L" })
        {
            var bytes = Svc.BuildTablePdf("گزارش عریض", "زیرنویس", "از تاریخ تا تاریخ", cols, rows, null, size);

            var box = Assert.Single(ParseMediaBoxes(bytes));
            Assert.InRange(box.Width, 594, 596);
            Assert.InRange(box.Height, 418, 421);
            Assert.True(box.Width > box.Height,
                $"[{size}] A5 افقی باید landscape باشد ولی MediaBox={box} شده.");

            var geometry = PdfSurfaceGeometry.Check(bytes);
            const double tol = 2.0;
            Assert.InRange(geometry.PageWidth, 594, 596);
            Assert.InRange(geometry.PageHeight, 418, 421);
            Assert.True(geometry.MaxDeviceX.HasValue && geometry.MaxDeviceY.HasValue,
                $"[{size}] هیچ محتوای قابل سنجشی نبود objects={geometry.ObjectsParsed} bt={geometry.BtCount}");
            Assert.InRange(geometry.MaxDeviceX!.Value, -tol, geometry.PageWidth + tol);
            Assert.InRange(geometry.MaxDeviceY!.Value, -tol, geometry.PageHeight + tol);
            Assert.True(geometry.MaxDeviceX.Value > 10,
                $"[{size}] MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");
        }
    }

    [Fact]
    public void BuildTablePdf_wide_columns_in_a5_auto_landscape_no_overflow()
    {
        // جداول عمومی «خودکار landscape» می‌شوند: با بیش از ۶ ستون حتی بدون پسوند L،
        // A5 باید افقی (۵۹۵×۴۲۰) بیرون بیاید و محتوا از لبه نزند — نه A5 پرترهٔ بریده.
        var cols = Enumerable.Range(1, 8)
            .Select(i => new TableReportColumn { Header = $"ستون {i}" })
            .ToList();
        var rows = new List<IReadOnlyList<string>> { Enumerable.Range(1, 8).Select(i => i.ToString()).ToList() };

        var bytes = Svc.BuildTablePdf("گزارش عریض", "زیرنویس", "از تاریخ تا تاریخ", cols, rows, null, "A5");
        var box = Assert.Single(ParseMediaBoxes(bytes));
        Assert.InRange(box.Width, 594, 596);
        Assert.InRange(box.Height, 418, 421);
        Assert.True(box.Width > box.Height,
            $"جدول ۸ ستونهٔ A5 باید خودکار landscape شود ولی MediaBox={box} شده.");

        var geometry = PdfSurfaceGeometry.Check(bytes);
        const double tol = 2.0;
        Assert.InRange(geometry.PageWidth, 594, 596);
        Assert.InRange(geometry.PageHeight, 418, 421);
        Assert.True(geometry.MaxDeviceX.HasValue && geometry.MaxDeviceY.HasValue,
            $"هیچ محتوای قابل سنجشی نبود objects={geometry.ObjectsParsed} bt={geometry.BtCount}");
        Assert.InRange(geometry.MaxDeviceX!.Value, -tol, geometry.PageWidth + tol);
        Assert.InRange(geometry.MaxDeviceY!.Value, -tol, geometry.PageHeight + tol);
        Assert.True(geometry.MaxDeviceX.Value > 10,
            $"MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");
    }

    // ─────────────────────── صفحه‌بندی فاکتورهای بلند ───────────────────────

    [Fact]
    public void Invoice_with_few_lines_is_a_single_page()
        => Assert.Equal(1, PageCount(Svc.BuildInvoicePdf(SampleInvoice(4), "A4")));

    [Fact]
    public void Invoice_with_many_lines_is_multi_page()
    {
        // فاکتور با ۴۰ ردیف باید به چند صفحه بریزد → شمارهٔ صفحه («صفحه N از M») واقعی می‌شود.
        var pageCount = PageCount(Svc.BuildInvoicePdf(SampleInvoice(40), "A4"));
        Assert.True(pageCount >= 2,
            $"فاکتور بلند باید چندصفحه‌ای شود ولی فقط {pageCount} صفحه دارد (صفحه‌بندی خراب/برگشته).");
    }

    // ─────────────── شمارش صفحات (CountPdfPages) — والد /Type /Pages نشمارد ───────────────

    /// <summary>
    /// گارد شمارندهٔ صفحهٔ <see cref="PdfReportService.CountPdfPages"/>: تعداد آبجکت‌های
    /// واقعیِ صفحه (هر کدام <c>/Type /Page</c>) را دقیق بشمارد و گرهٔ والدِ درخت صفحات
    /// (<c>/Type /Pages</c>) را نشمارد — وگرنه هر خروجی یک صفحهٔ اضافی می‌گیرد و کاربر
    /// «چندصفحه خواهد شد» را اشتباه می‌بیند (چیپ تعداد صفحهٔ دیالوگ چاپ سند).
    /// </summary>
    [Theory]
    [InlineData(1)]
    [InlineData(3)]
    [InlineData(7)]
    public void CountPdfPages_counts_only_page_objects_not_the_Pages_parent(int pageObjects)
    {
        // PDF دست‌ساز با pageObjects آبجکتِ واقعیِ /Type /Page + یک والدِ /Type /Pages
        // (و catalog که /Type /Catalog است). اگر شمارنده اشتباهاً والد را هم بشمارد،
        // خروجی pageObjects+1 می‌شود — Assert.Equal همین را می‌گیرد.
        var pdf = CraftMinimalPdf(pageObjects);

        Assert.Equal(pageObjects, PdfReportService.CountPdfPages(pdf));
    }

    [Fact]
    public void CountPdfPages_ignores_page_like_types_and_returns_zero_for_empty()
    {
        // نوع‌های «شبه‌صفحه» (با پیشوند Page ولی نه واقعی) نباید شمرده شوند:
        // /Type /PageLabel و /Type /PageMode در واقعیتِ PDF فقط در ریشه هستند ولی
        // در یک رشتهٔ خام باید با همین regex رد شوند — پس رگرسیونِ شمارش نادرست را می‌گیرد.
        var fake = Encoding.Latin1.GetBytes(
            "1 0 obj\n<< /Type /PageLabel /Nums [0 << /P (a) /S /D >>] >>\nendobj\n" +
            "2 0 obj\n<< /Type /PageMode /UseNone >>\nendobj\n" +
            "%%EOF\n");
        Assert.Equal(0, PdfReportService.CountPdfPages(fake));

        // تهی‌ها: null و خالی باید ۰ برگردانند نه استثنا.
        Assert.Equal(0, PdfReportService.CountPdfPages(Array.Empty<byte>()));
        Assert.Equal(0, PdfReportService.CountPdfPages(null!));
    }

    [Fact]
    public void CountPdfPages_matches_real_QuestPDF_output_paging()
    {
        // روی خروجی‌های واقعی QuestPDF، شمارنده باید با صفحه‌بندیِ سرویس یکی شود:
        // فاکتور کوتاه = ۱ صفحه، فاکتور بلند = ≥ ۲ صفحه (مثل PageCount ولی با مکانیزم
        // /Type /Page — دو مکانیزم مستقل که نمی‌توانند هم‌زمان خراب شوند).
        Assert.Equal(1, PdfReportService.CountPdfPages(Svc.BuildInvoicePdf(SampleInvoice(4), "A4")));

        var many = Svc.BuildInvoicePdf(SampleInvoice(40), "A4");
        Assert.True(PdfReportService.CountPdfPages(many) >= 2,
            $"فاکتور بلند باید چندصفحه‍ باشد ولی CountPdfPages={PdfReportService.CountPdfPages(many)}");

        // هم‌راستا با MediaBox های واقعیِ صفحه‌ها: هر صفحهٔ واقعی MediaBox خودش را دارد
        // و والدِ /Type /Pages نه — پس تعداد MediaBox ها باید دقیقاً == تعداد صفحه باشد.
        Assert.Equal(ParseMediaBoxes(many).Count, PdfReportService.CountPdfPages(many));
    }

    /// <summary>
    /// ساخت PDF دست‌سازِ حداقلی با یک والدِ /Type /Pages و pageObjects آبجکتِ
    /// /Type /Page — برای گارد شمارندهٔ صفحه بدون وابستگی به QuestPDF.
    /// </summary>
    private static byte[] CraftMinimalPdf(int pageObjects)
    {
        var sb = new StringBuilder();
        sb.AppendLine("%PDF-1.4");
        sb.AppendLine("1 0 obj");
        sb.AppendLine("<< /Type /Catalog /Pages 2 0 R >>");
        sb.AppendLine("endobj");
        sb.AppendLine("2 0 obj");
        var kids = string.Join(" ", Enumerable.Range(3, pageObjects).Select(i => $"{i} 0 R"));
        sb.AppendLine($"<< /Type /Pages /Kids [{kids}] /Count {pageObjects} >>");
        sb.AppendLine("endobj");
        for (var i = 3; i < 3 + pageObjects; i++)
        {
            sb.AppendLine($"{i} 0 obj");
            sb.AppendLine($"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents {i} 0 R >>");
            sb.AppendLine("endobj");
        }
        sb.AppendLine("trailer");
        sb.AppendLine("<< /Root 1 0 R >>");
        sb.AppendLine("%%EOF");
        return Encoding.Latin1.GetBytes(sb.ToString());
    }


    // ─────────────── قالب عمومی (BuildTemplatePdf) در A5 افقی ───────────────

    [Fact]
    public void BuildTemplatePdf_a5l_landscape_media_box_and_no_overflow()
    {
        // گارد موتور چاپ عمومی: وقتی قالب با A5 افقی («A5L») ساخته می‌شود، MediaBox باید
        // دقیقاً ۵۹۵×۴۲۰ (A5 landscape = PageSizes.A5.Landscape()≈595.28×419.53) باشد و
        // هیچ محتوای واقعی‌ای از لبهٔ صفحه بیرون نزند — هم‌دهان با گاردهای سند/فاکتور.
        var svc = new PdfReportService();
        var tpl = SampleTemplate();

        foreach (var size in new[] { "A5L" })
        {
            var bytes = svc.BuildTemplatePdf(tpl, SamplePrintData(), size);

            var box = Assert.Single(ParseMediaBoxes(bytes));
            // پنجرهٔ دقیق ۵۹۵×۴۲۰ (تلورانس قرینه‌سازی ۵۹۵.۲۸/۴۱۹.۵۳).
            Assert.InRange(box.Width, 594, 596);
            Assert.InRange(box.Height, 418, 421);
            // افقی بودن را هم صریح نگهبانی کن (عرض > ارتفاع).
            Assert.True(box.Width > box.Height,
                $"[{size}] A5 افقی باید landscape باشد ولی MediaBox={box} شده.");

            // بدون بیرون‌زدگی: مختصاتِ واقعی رسم (پس از CTM/FlateDecode) باید درون MediaBox بماند.
            var geometry = PdfSurfaceGeometry.Check(bytes);
            const double tol = 2.0;
            Assert.InRange(geometry.PageWidth, 594, 596);
            Assert.InRange(geometry.PageHeight, 418, 421);
            Assert.True(geometry.MaxDeviceX.HasValue && geometry.MaxDeviceY.HasValue,
                $"[{size}] هیچ محتوای قابل سنجشی نبود objects={geometry.ObjectsParsed} bt={geometry.BtCount}");
            Assert.InRange(geometry.MaxDeviceX!.Value, -tol, geometry.PageWidth + tol);
            Assert.InRange(geometry.MaxDeviceY!.Value, -tol, geometry.PageHeight + tol);
            Assert.True(geometry.MaxDeviceX.Value > 10,
                $"[{size}] MaxDeviceX محتوای واقعی نیست maxX={geometry.MaxDeviceX.Value}");
        }
    }

    // ─────────────────── راست‌به‌چپ بودن (RTL) — گاردِ سطحِ منبع ───────────────────

    [Fact]
    public void Cell_helpers_keep_text_right_aligned_RTL()
    {
        // راست‌چینی سلول‌ها را در سطح منبع نگهبانی می‌کنیم — این مستقیماً همان
        // «چپ‌چین شدن ستون‌ها» را می‌گیرد که قبلاً گزارش شد (بازگشت AlignRight به AlignLeft).
        var src = ReadSource("Tarazin.Ui", "Services", "PdfReportService.cs");

        // نسخهٔ مقیاس‌پذیر (که فشرده‌سازی خودکار فاکتور «یک صفحه» از آن استفاده می‌کند)
        // محل واقعی AlignRight است — و هدر/بدنهٔ معمولی باید به همان‌جا delegate کنند.
        Assert.True(
            ContainsAlignRightIn(ExpressionBody(src, "HeaderCellScaled")),
            "HeaderCellScaled باید سلول هدر را راست‌چین (AlignRight) کند — باگ RTL برگشته.");

        Assert.True(
            ContainsAlignRightIn(ExpressionBody(src, "BodyCellScaled")),
            "BodyCellScaled باید سلول بدنه را راست‌چین (AlignRight) کند — باگ RTL برگشته.");

        // سلول‌های معمولی نباید AlignRight را دور بزنند — باید به نسخهٔ مقیاس‌پذیر delegate کنند.
        Assert.True(
            ExpressionBody(src, "HeaderCell").Contains("HeaderCellScaled", StringComparison.Ordinal),
            "HeaderCell باید به HeaderCellScaled delegate کند تا RTL و مقیاس‌پذیری یک‌جا بمانند");
        Assert.True(
            ExpressionBody(src, "BodyCell").Contains("BodyCellScaled", StringComparison.Ordinal),
            "BodyCell باید به BodyCellScaled delegate کند تا RTL و مقیاس‌پذیری یک‌جا بمانند");
    }

    // ─────────────────────────── دادهٔ نمونه ───────────────────────────

    private static PrintTemplateDef SampleTemplate() => new()
    {
        Id = "treasury.cheques",
        Name = "چک‌ها",
        PaperSize = PrintPaperSize.A4,
        Orientation = PrintOrientation.Portrait,
        MarginMm = 8,
        FontSizePt = 8f,
        ShowCompanyHeader = true,
        ShowPageFooter = true,
        ShowReportFooter = true,
        Columns = new List<PrintColumnDef>
        {
            new() { Key = "ChequeNumber", Title = "شماره چک", Width = 90 },
            new() { Key = "BankName", Title = "بانک", Width = 110 },
            new() { Key = "Amount", Title = "مبلغ", Width = 120, Format = "N0", Total = true }
        }
    };

    private static PrintDataModel SamplePrintData()
    {
        var data = new PrintDataModel
        {
            CompanyName = "ترازین",
            Title = "گزارش چک‌ها",
            RangeText = "از 1405/06/01 تا 1405/06/06",
            QrEnabled = false
        };
        data.Rows.Add(new PrintRow { ["ChequeNumber"] = "CHQ-1", ["BankName"] = "بانک صادرات", ["Amount"] = 500000000m });
        data.Rows.Add(new PrintRow { ["ChequeNumber"] = "CHQ-2", ["BankName"] = "بانک ملی", ["Amount"] = 20000000m });
        return data;
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

    private static List<ChequeDueRow> SampleCheques() => new()
    {
        new ChequeDueRow
        {
            ChequeNumber = "CHQ-50001", BankName = "بانک صادرات ایران", Amount = 500_000_000,
            Direction = "In", Status = "Pending", SourceReference = "GoldInvoice:SL-1001",
            DaysToDue = -4, AlertLevel = "Overdue"
        },
        new ChequeDueRow
        {
            ChequeNumber = "CHQ-10001", BankName = "بانک ملی ایران", Amount = 75_000_000,
            Direction = "In", Status = "Pending", DaysToDue = 26, AlertLevel = "OnTime"
        }
    };

    // ─────────────────────────── خروجی کمکی ───────────────────────────

    private readonly record struct MediaBox(int Width, int Height)
    {
        public override string ToString() => $"{Width + "×" + Height}";
    }

    private static readonly Regex MediaBoxRe = new(
        @"/MediaBox\s*\[\s*([\w.\-+eE\s]+)\s*\]",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    /// <summary>همهٔ MediaBox های صفحات PDF را از بایت‌های خام بدون decompress استخراج می‌کند.</summary>
    private static List<MediaBox> ParseMediaBoxes(byte[] pdf)
    {
        var text = Encoding.Latin1.GetString(pdf);
        var boxes = new List<MediaBox>();
        foreach (Match m in MediaBoxRe.Matches(text))
        {
            var nums = Regex.Matches(m.Groups[1].Value, @"[\d.]+")
                .Select(mm => (int)Math.Round(decimal.Parse(mm.Value, CultureInfo.InvariantCulture)))
                .ToList();
            if (nums.Count >= 4)
                boxes.Add(new MediaBox(nums[2], nums[3])); // [llx lly urx ury] → عرض، ارتفاع
        }
        return boxes;
    }

    /// <summary>تعداد صفحات = مقدار تاریخچهٔ Pages tree (مؤثق و بدون decompress).</summary>
    private static int PageCount(byte[] pdf)
    {
        var m = Regex.Match(Encoding.Latin1.GetString(pdf), @"/Count (\d+)");
        return m.Success ? int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) : 0;
    }

    // ─────────── ابزارهای گاردِ منبع (RTL) ───────────

    /// <summary>ریشهٔ repo را از محل اجرای تست پیدا می‌کند (پوشه‌ای که شامل Tarazin.Ui است).</summary>
    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (var d = dir; d != null; d = d.Parent)
        {
            if (Directory.Exists(Path.Combine(d.FullName, "Tarazin.Ui")) &&
                Directory.Exists(Path.Combine(d.FullName, "Tarazin.Share")))
                return d.FullName;
        }
        throw new Xunit.Sdk.XunitException(
            "ریشهٔ repo پیدا نشد (از " + AppContext.BaseDirectory + ").");
    }

    private static string ReadSource(params string[] relPath)
    {
        var full = Path.Combine(new[] { RepoRoot() }.Concat(relPath).ToArray());
        if (!File.Exists(full))
            throw new Xunit.Sdk.XunitException("منبع یافت نشد: " + full);
        return File.ReadAllText(full);
    }

    /// <summary>
    /// بدنهٔ یک متد expression-bodied (تا اولین «;») براساس امضای آغازین آن را برمی‌گرداند؛
    /// برای سلول‌هایی مثل <c>private static IContainer HeaderCell(IContainer c) =&gt; c.…;</c>.
    /// </summary>
    private static string ExpressionBody(string source, string methodName)
    {
        // نشانگر امضا: «(IContainer c» — هم برای (IContainer c) و هم (IContainer c, float s)
        var start = source.IndexOf(methodName + "(IContainer c", StringComparison.Ordinal);
        if (start < 0) return "";
        var bodyStart = source.IndexOf('>', start);          // «=>»
        var end = source.IndexOf(';', bodyStart);
        return bodyStart < 0 || end < 0 ? "" : source.Substring(bodyStart, end - bodyStart);
    }

    private static bool ContainsAlignRightIn(string body)
        => body.Contains(".AlignRight()", StringComparison.Ordinal);
}