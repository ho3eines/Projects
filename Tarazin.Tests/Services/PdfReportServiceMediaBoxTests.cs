using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using QuestPDF.Helpers;
using Tarazin.Models;
using Tarazin.Services;
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

    // ─────────────────── راست‌به‌چپ بودن (RTL) — گاردِ سطحِ منبع ───────────────────

    [Fact]
    public void Cell_helpers_keep_text_right_aligned_RTL()
    {
        // راست‌چینی سلول‌ها را در سطح منبع نگهبانی می‌کنیم — این مستقیماً همان
        // «چپ‌چین شدن ستون‌ها» را می‌گیرد که قبلاً گزارش شد (بازگشت AlignRight به AlignLeft).
        var src = ReadSource("Tarazin.Ui", "Services", "PdfReportService.cs");

        Assert.True(
            ContainsAlignRightIn(ExpressionBody(src, "HeaderCell")),
            "HeaderCell باید سلول هدر را راست‌چین (AlignRight) کند — باگ RTL برگشته.");

        Assert.True(
            ContainsAlignRightIn(ExpressionBody(src, "BodyCell")),
            "BodyCell باید سلول بدنه را راست‌چین (AlignRight) کند — باگ RTL برگشته.");
    }

    // ─────────────────────────── دادهٔ نمونه ───────────────────────────

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
        var marker = methodName + "(IContainer c)";
        var start = source.IndexOf(marker, StringComparison.Ordinal);
        if (start < 0) return "";
        var bodyStart = source.IndexOf('>', start);          // «=>»
        var end = source.IndexOf(';', bodyStart);
        return bodyStart < 0 || end < 0 ? "" : source.Substring(bodyStart, end - bodyStart);
    }

    private static bool ContainsAlignRightIn(string body)
        => body.Contains(".AlignRight()", StringComparison.Ordinal);
}