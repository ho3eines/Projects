using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// ساخت PDF با QuestPDF — موتور مشترک وب + MAUI.
///
/// - هاست وب (Blazor Server): این سرویس روی سرور اجرا می‌شود → PDF واقعاً سمت
///   سرور ساخته می‌شود (جایگزین html2pdf که در مرورگر/WebView سنگین است).
/// - هاست MAUI: همین کد در فرایند بومی اپ اجرا می‌شود (SkiaSharp) — بدون
///   رندر DOM/Canvas در WebView، بنابراین روی موبایل سبک و سریع است.
///
/// فونت Vazirmatn به‌صورت EmbeddedResource همراه اسمبلی است تا در همهٔ
/// پلتفرم‌ها (وب + اندروید/iOS/ویندوز) بدون CDN در دسترس باشد.
/// </summary>
public sealed class PdfReportService
{
    public const string FontFamily = "Vazirmatn";

    private static readonly CultureInfo Fa = CultureInfo.GetCultureInfo("fa-IR");

    static PdfReportService()
    {
        // مجوز Community کوئست‌پی‌دی‌اف (رایگان برای شرکت‌های با درآمد کمتر از ۱ میلیون دلار).
        QuestPDF.Settings.License = LicenseType.Community;
        RegisterVazirmatnFonts();
    }

    public PdfReportService()
    {
        // سازندهٔ عمومی برای DI — فونت‌ها در static ctor یک‌بار ثبت می‌شوند.
    }

    private static void RegisterVazirmatnFonts()
    {
        try
        {
            var assembly = typeof(PdfReportService).Assembly;
            using var regular = assembly.GetManifestResourceStream("Tarazin.Ui.fonts.Vazirmatn-Regular.ttf");
            if (regular is not null)
                QuestPDF.Drawing.FontManager.RegisterFont(regular);

            using var bold = assembly.GetManifestResourceStream("Tarazin.Ui.fonts.Vazirmatn-Bold.ttf");
            if (bold is not null)
                QuestPDF.Drawing.FontManager.RegisterFont(bold);
        }
        catch
        {
            // اگر فونت ثبت نشود، QuestPDF به فونت پیش‌فرض (Helvetica) برمی‌گردد؛
            // خطا نباید چاپ/دانلود را بشکند.
        }
    }

    // ─────────────────────────── فاکتور طلا ───────────────────────────

    /// <summary>ساخت PDF فاکتور خرید/فروش طلا (A4 یا A5 پرتره).</summary>
    public byte[] BuildInvoicePdf(GoldInvoicePrintModel model, string paperSize = "A4")
    {
        var isA5 = string.Equals(paperSize, "A5", StringComparison.OrdinalIgnoreCase);
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 20 : 28);
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(9).FontColor("#1f2937"));

                page.Header().Element(h => BuildOfficialHeader(h, isA5,
                    $"{TypeTitle(model.InvoiceType)} طلا و جواهرات — {model.InvoiceNumber}"));

                page.Content().Column(col =>
                {
                    col.Item().Element(c => BuildInvoiceMeta(c, model));
                    col.Item().PaddingTop(8).Element(c => BuildInvoiceLines(c, model));
                    col.Item().PaddingTop(8).Element(c => BuildInvoiceTotals(c, model));
                    col.Item().PaddingTop(8).Element(c => BuildSettlement(c, model));
                });

                page.Footer().Element(f => BuildOfficialFooter(f, isA5, $"فاکتور {model.InvoiceNumber}"));
            });
        }).GeneratePdf();
    }

    private static string TypeTitle(string type)
        => string.Equals(type, "Purchase", StringComparison.OrdinalIgnoreCase) ? "فاکتور خرید" : "فاکتور فروش";

    private static void BuildInvoiceMeta(IContainer c, GoldInvoicePrintModel model)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Padding(8).Row(row =>
        {
            // ترتیب RTL: «شماره فاکتور» باید راست‌ترین (اولینِ خوانده‌شده) باشد.
            row.RelativeItem().Column(meta =>
            {
                meta.Item().Text($"سند حسابداری: {model.DocumentId:N0}").Bold();
                meta.Item().Text($"مالیات: ٪{model.TaxPct:0.#}");
            });
            row.RelativeItem().Column(meta =>
            {
                meta.Item().Text($"مشتری: {model.PartyName}").Bold();
                if (!string.IsNullOrWhiteSpace(model.DetailCode))
                    meta.Item().Text($"کد تفصیلی: {model.DetailCode}");
            });
            row.RelativeItem().AlignRight().Column(meta =>
            {
                meta.Item().Text($"شماره فاکتور: {model.InvoiceNumber}").Bold();
                meta.Item().Text($"تاریخ: {model.InvoiceDate.ToString("yyyy/MM/dd", Fa)}");
            });
        });
    }

    private static void BuildInvoiceLines(IContainer c, GoldInvoicePrintModel model)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // ترتیب RTL: «ردیف» باید راست‌ترین ستون باشد → ستون‌ها برعکس تعریف می‌شوند.
            table.ColumnsDefinition(cols =>
            {
                cols.RelativeColumn(3);    // جمع ردیف
                cols.RelativeColumn(2.5f); // سود
                cols.RelativeColumn(2.5f); // اجرت
                cols.RelativeColumn(3);    // نرخ / قیمت
                cols.RelativeColumn(2);    // مقدار
                cols.RelativeColumn(4);    // کالا / ارز
                cols.RelativeColumn(2);    // نوع
                cols.ConstantColumn(24);   // ردیف
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("جمع ردیف").Bold();
                h.Cell().Element(HeaderCell).Text("سود").Bold();
                h.Cell().Element(HeaderCell).Text("اجرت").Bold();
                h.Cell().Element(HeaderCell).Text("نرخ / قیمت").Bold();
                h.Cell().Element(HeaderCell).Text("مقدار").Bold();
                h.Cell().Element(HeaderCell).Text("کالا / ارز").Bold();
                h.Cell().Element(HeaderCell).Text("نوع").Bold();
                h.Cell().Element(HeaderCell).Text("ردیف").Bold();
            });

            var i = 1;
            foreach (var line in model.Lines)
            {
                var index = i++;
                table.Cell().Element(BodyCell).AlignRight().Text(LineTotal(line).ToString("N0", Fa));
                table.Cell().Element(BodyCell).AlignRight().Text(line.Profit.ToString("N0", Fa));
                table.Cell().Element(BodyCell).AlignRight().Text(line.Workmanship.ToString("N0", Fa));
                table.Cell().Element(BodyCell).AlignRight().Text(line.RowType == "Gold"
                    ? line.Price.ToString("N0", Fa)
                    : line.ResolvedRate.ToString("N0", Fa));
                table.Cell().Element(BodyCell).Text(FormatQty(line));
                table.Cell().Element(BodyCell).Text(line.Title);
                table.Cell().Element(BodyCell).Text(line.RowType == "Gold" ? "طلا" : "ارز");
                table.Cell().Element(BodyCell).Text(index.ToString());
            }
        });
    }

    private static decimal LineTotal(GoldInvoicePrintLine line)
    {
        if (line.RowType == "Gold")
        {
            var baseAmount = line.Qty * line.Price;
            return baseAmount + line.Workmanship + line.Profit;
        }

        // ارز: مقدار × نرخ تبدیل
        return line.Qty * line.ResolvedRate;
    }

    private static string FormatQty(GoldInvoicePrintLine line)
        => line.RowType == "Gold"
            ? $"{line.Qty:N3} گرم"
            : $"{line.Qty:N2} {line.CurrencyCode}";

    private static void BuildInvoiceTotals(IContainer c, GoldInvoicePrintModel model)
    {
        c.PaddingTop(4).Row(row =>
        {
            row.RelativeItem();
            row.ConstantItem(220).Border(0.8f).BorderColor("#d1d5db").Padding(8).Column(total =>
            {
                total.Item().Row(r =>
                {
                    r.RelativeItem().Text("جمع پایه");
                    r.RelativeItem().AlignRight().Text(model.TotalBase.ToString("N0", Fa));
                });
                total.Item().Row(r =>
                {
                    r.RelativeItem().Text($"مالیات (٪{model.TaxPct:0.#})");
                    r.RelativeItem().AlignRight().Text(model.TotalTax.ToString("N0", Fa));
                });
                total.Item().PaddingTop(4).Row(r =>
                {
                    r.RelativeItem().Text("جمع کل فاکتور").Bold();
                    r.RelativeItem().AlignRight().Text(model.TotalAmount.ToString("N0", Fa) + " ریال").Bold();
                });
            });
        });
    }

    private static void BuildSettlement(IContainer c, GoldInvoicePrintModel model)
    {
        var parts = new List<string>();
        if (model.PayCash > 0) parts.Add($"نقدی: {model.PayCash:N0} ریال");
        if (model.PayBank > 0) parts.Add($"بانک: {model.PayBank:N0} ریال");
        if (model.PayGoldGram > 0) parts.Add($"طلا: {model.PayGoldGram:N3} گرم");
        if (model.PayCurrencyQty > 0)
            parts.Add($"ارز: {model.PayCurrencyQty:N2} {model.PayCurrencyCode} (نرخ {model.PayCurrencyRate:N0})");
        if (model.PayChequeAmount > 0)
        {
            var chq = $"چک: {model.PayChequeAmount:N0} ریال";
            if (!string.IsNullOrWhiteSpace(model.ChequeNumber))
                chq += $" ({model.ChequeNumber} — {model.ChequeBankName})";
            if (model.ChequeDueDate.HasValue)
                chq += $" — سررسید {model.ChequeDueDate.Value.ToString("yyyy/MM/dd", Fa)}";
            parts.Add(chq);
        }
        if (model.BalanceRial > 0) parts.Add($"مانده (نسیه): {model.BalanceRial:N0} ریال");
        if (parts.Count == 0) parts.Add("—");

        c.Row(row =>
        {
            // RTL: برچسب «روش تسویه» راست‌ترین و مقدارها سمت چپ آن می‌نشینند.
            row.RelativeItem().AlignRight().Text(string.Join("   |   ", parts));
            row.RelativeItem().AlignRight().Text("روش تسویه").Bold();
        });
    }

    // ─────────────────────────── سند حسابداری ───────────────────────────

    /// <summary>ساخت PDF سند حسابداری (ساده یا پیشرفته — A4/A5 پرتره).</summary>
    public byte[] BuildDocumentPdf(AccountingDocumentPrintModel model, string paperSize = "A4")
    {
        var isA5 = string.Equals(paperSize, "A5", StringComparison.OrdinalIgnoreCase);
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 18 : 22);
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(9).FontColor("#1f2937"));

                page.Header().Element(h => BuildOfficialHeader(h, isA5, $"سند حسابداری — {model.DocumentNumber}"));

                page.Content().Column(col =>
                {
                    col.Item().Element(c => BuildDocumentMeta(c, model));
                    col.Item().PaddingTop(6).Element(c => BuildDocumentTable(c, model));
                    col.Item().PaddingTop(6).Element(c => BuildDocumentTotals(c, model));
                });

                page.Footer().Element(f => BuildOfficialFooter(f, isA5, $"سند {model.DocumentNumber}"));
            });
        }).GeneratePdf();
    }

    private static void BuildDocumentMeta(IContainer c, AccountingDocumentPrintModel model)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Padding(6).Row(row =>
        {
            row.RelativeItem().Column(meta =>
            {
                meta.Item().Text($"شماره سند: {model.DocumentNumber}").Bold();
                meta.Item().Text($"وضعیت: {AccountingDocumentStatus.Title(model.Status)}");
            });
            row.RelativeItem().Column(meta =>
            {
                if (!string.IsNullOrWhiteSpace(model.CounterPartyName))
                    meta.Item().Text($"طرف حساب: {model.CounterPartyName}");
                meta.Item().Text($"نوع: {TypeDocLabel(model.DocumentType)}");
            });
            row.RelativeItem().AlignRight().Column(meta =>
            {
                meta.Item().Text($"تاریخ: {model.DocumentDate.ToString("yyyy/MM/dd", Fa)}").Bold();
                meta.Item().Text($"مبلغ کل: {model.TotalAmount:N0} ریال");
            });
        });
    }

    private static void BuildDocumentTable(IContainer c, AccountingDocumentPrintModel model)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            table.ColumnsDefinition(cols =>
            {
                cols.RelativeColumn(1.5f); // بستانکار
                cols.RelativeColumn(1.5f); // بدهکار
                cols.RelativeColumn(3);    // عنوان / شرح
                cols.RelativeColumn(1.2f);// کد
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("بستانکار").Bold();
                h.Cell().Element(HeaderCell).Text("بدهکار").Bold();
                h.Cell().Element(HeaderCell).Text("عنوان / شرح").Bold();
                h.Cell().Element(HeaderCell).Text("کد").Bold();
            });

            foreach (var line in model.Lines)
            {
                table.Cell().Element(BodyCell).AlignRight().Text(line.Credit > 0 ? line.Credit.ToString("N0", Fa) : "");
                table.Cell().Element(BodyCell).AlignRight().Text(line.Debit > 0 ? line.Debit.ToString("N0", Fa) : "");
                table.Cell().Element(BodyCell).Text(LineLabel(line));
                table.Cell().Element(BodyCell).Text(line.AccountCode);
            }
        });
    }

    private static string LineLabel(DocumentLineRow line)
        => string.IsNullOrWhiteSpace(line.Description) ? line.Title : $"{line.Title} — {line.Description}";

    private static void BuildDocumentTotals(IContainer c, AccountingDocumentPrintModel model)
    {
        c.PaddingTop(2).Row(row =>
        {
            row.RelativeItem();
            row.ConstantItem(240).Border(0.8f).BorderColor("#d1d5db").Padding(6).Column(total =>
            {
                total.Item().Row(r =>
                {
                    r.RelativeItem().Text("جمع بدهکار");
                    r.RelativeItem().AlignRight().Text(model.TotalDebit.ToString("N0", Fa));
                });
                total.Item().Row(r =>
                {
                    r.RelativeItem().Text("جمع بستانکار");
                    r.RelativeItem().AlignRight().Text(model.TotalCredit.ToString("N0", Fa));
                });
                total.Item().PaddingTop(2).Row(r =>
                {
                    r.RelativeItem().Text(model.TotalDebit == model.TotalCredit ? "✔ متوازن" : "✘ نامتوازن").Bold()
                        .FontColor(model.TotalDebit == model.TotalCredit ? "#059669" : "#dc2626");
                });
            });
        });
    }

    private static string TypeDocLabel(string? t) => (t ?? "") switch
    {
        "Journal" => "سند روزنامه",
        "Receipt" => "دریافت",
        "Payment" => "پرداخت",
        "Purchase" => "خرید",
        "Sale" => "فروش",
        _ => t ?? ""
    };

    // ─────────────────────────── گزارش چک‌ها ───────────────────────────

    /// <summary>ساخت PDF گزارش چک‌های در جریان و سررسیدشده (A4/A5 landscape).</summary>
    public byte[] BuildChequeReportPdf(IEnumerable<ChequeDueRow> rows, string paperSize = "A4")
    {
        var list = rows?.ToList() ?? new List<ChequeDueRow>();
        var isA5 = string.Equals(paperSize, "A5", StringComparison.OrdinalIgnoreCase);
        var pageSize = isA5 ? PageSizes.A5.Landscape() : PageSizes.A4.Landscape();

        var overdue = list.Count(r => r.AlertLevel == "Overdue");
        var dueSoon = list.Count(r => r.AlertLevel == "DueSoon");
        var overdueAmount = list.Where(r => r.AlertLevel == "Overdue").Sum(r => r.Amount);

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 18 : 24);
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(8.5f).FontColor("#1f2937"));

                page.Header().Element(h => BuildOfficialHeader(h, isA5,
                    $"گزارش چک‌های در جریان و سررسیدشده — تهیه شده در {DateTime.Now:yyyy/MM/dd HH:mm}"));

                page.Content().Column(col =>
                {
                    col.Item().Element(c => BuildChequeSummary(c, list.Count, overdue, dueSoon, overdueAmount));
                    col.Item().PaddingTop(8).Element(c => BuildChequeTable(c, list));
                });

                page.Footer().Element(f => BuildOfficialFooter(f, isA5, "گزارش چک‌ها"));
            });
        }).GeneratePdf();
    }

    private static void BuildChequeSummary(IContainer c, int total, int overdue, int dueSoon, decimal overdueAmount)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Padding(8).Row(row =>
        {
            // ترتیب RTL: «چک‌های باز» باید راست‌ترین کارت باشد.
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("جمع سررسیدشده").FontColor("#dc2626");
                x.Item().Text(overdueAmount.ToString("N0", Fa) + " ریال").FontSize(14).Bold().FontColor("#dc2626");
            });
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("سررسید نزدیک").FontColor("#d97706");
                x.Item().Text(dueSoon.ToString("N0", Fa)).FontSize(14).Bold().FontColor("#d97706");
            });
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("سررسیدشده").FontColor("#dc2626");
                x.Item().Text(overdue.ToString("N0", Fa)).FontSize(14).Bold().FontColor("#dc2626");
            });
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("چک‌های باز").FontColor("#6b7280");
                x.Item().Text(total.ToString("N0", Fa)).FontSize(14).Bold();
            });
        });
    }

    private static void BuildChequeTable(IContainer c, List<ChequeDueRow> rows)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // ترتیب RTL: «شماره چک» باید راست‌ترین ستون باشد → ستون‌ها برعکس تعریف می‌شوند.
            table.ColumnsDefinition(cols =>
            {
                cols.RelativeColumn(1.8f); // منبع
                cols.RelativeColumn(1.5f); // هشدار
                cols.RelativeColumn(1.5f); // وضعیت
                cols.RelativeColumn(1.8f); // مانده تا سررسید
                cols.RelativeColumn(1.8f); // سررسید
                cols.RelativeColumn(2);    // مبلغ
                cols.RelativeColumn(1.2f); // جهت
                cols.RelativeColumn(2);    // بانک
                cols.RelativeColumn(2);    // شماره
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("منبع").Bold();
                h.Cell().Element(HeaderCell).Text("هشدار").Bold();
                h.Cell().Element(HeaderCell).Text("وضعیت").Bold();
                h.Cell().Element(HeaderCell).Text("مانده تا سررسید").Bold();
                h.Cell().Element(HeaderCell).Text("سررسید").Bold();
                h.Cell().Element(HeaderCell).Text("مبلغ").Bold();
                h.Cell().Element(HeaderCell).Text("جهت").Bold();
                h.Cell().Element(HeaderCell).Text("بانک").Bold();
                h.Cell().Element(HeaderCell).Text("شماره چک").Bold();
            });

            foreach (var chq in rows)
            {
                var alertColor = chq.AlertLevel switch
                {
                    "Overdue" => "#dc2626",
                    "DueSoon" => "#d97706",
                    _ => "#059669"
                };

                table.Cell().Element(BodyCell).Text(SourceLabel(chq.SourceReference));
                table.Cell().Element(BodyCell).Text(AlertLabel(chq.AlertLevel)).FontColor(alertColor).Bold();
                table.Cell().Element(BodyCell).Text(StatusLabel(chq.Status));
                table.Cell().Element(BodyCell).Text(DueLabel(chq.DaysToDue));
                table.Cell().Element(BodyCell).Text(chq.DueDate?.ToString("yyyy/MM/dd", Fa) ?? "—");
                table.Cell().Element(BodyCell).AlignRight().Text(chq.Amount.ToString("N0", Fa));
                table.Cell().Element(BodyCell).Text(chq.Direction == "In" ? "دریافتی" : "پرداختی");
                table.Cell().Element(BodyCell).Text(chq.BankName);
                table.Cell().Element(BodyCell).Text(chq.ChequeNumber);
            }
        });
    }

    // ─────────────── جدول عمومی (خط لولهٔ مشترک همهٔ گزارش‌ها) ───────────────

    /// <summary>
    /// ساخت PDF برای هر گزارش جدولی — خط لولهٔ مشترک همهٔ گزارش‌ها.
    /// جدول عریض (بیش از ۶ ستون) خودکار landscape می‌شود؛ اندازهٔ A4/A5 از
    /// سلکتور دیالوگ چاپ می‌آید. ردیف‌ها از قبل به رشته آماده می‌شوند.
    /// </summary>
    public byte[] BuildTablePdf(
        string title,
        string subtitle,
        string rangeText,
        IReadOnlyList<TableReportColumn> columns,
        IReadOnlyList<IReadOnlyList<string>> rows,
        IReadOnlyList<string>? summaryLines = null,
        string paperSize = "A4")
    {
        var isA5 = string.Equals(paperSize, "A5", StringComparison.OrdinalIgnoreCase);
        var landscape = columns.Count > 6;
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;
        if (landscape)
            pageSize = pageSize.Landscape();

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 18 : 22);
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(8.5f).FontColor("#1f2937"));

                page.Header().Element(h => BuildOfficialHeader(h, isA5, title));

                page.Content().Column(col =>
                {
                    col.Item().Text(subtitle).FontSize(9).FontColor("#6b7280");
                    if (!string.IsNullOrWhiteSpace(rangeText))
                        col.Item().PaddingTop(2).Text($"بازه: {rangeText}").FontSize(8).FontColor("#9ca3af");

                    col.Item().PaddingTop(8).Element(c => BuildGenericTable(c, columns, rows));
                    if (summaryLines is { Count: > 0 })
                        col.Item().PaddingTop(8).Element(c => BuildGenericSummary(c, summaryLines));
                });

                page.Footer().Element(f => BuildOfficialFooter(f, isA5, title));
            });
        }).GeneratePdf();
    }

    private static void BuildGenericTable(IContainer c, IReadOnlyList<TableReportColumn> columns, IReadOnlyList<IReadOnlyList<string>> rows)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // ترتیب RTL: اولین ستونِ منطقی باید راست‌ترین رندر شود → ستون‌ها و سلول‌ها
            // از آخر به اول (برعکس) پیمایش می‌شوند تا جدولِ فارسی راست‌به‌چپ خوانده شود.
            table.ColumnsDefinition(cols =>
            {
                for (var i = columns.Count - 1; i >= 0; i--)
                    cols.RelativeColumn(1);
            });

            table.Header(h =>
            {
                for (var i = columns.Count - 1; i >= 0; i--)
                    // هدر فارسی همیشه راست‌چین (RTL).
                    h.Cell().Element(HeaderCell).AlignRight().Text(columns[i].Header).Bold();
            });

            foreach (var row in rows)
            {
                for (var i = columns.Count - 1; i >= 0; i--)
                {
                    var text = i < row.Count ? row[i] ?? "" : "";
                    // متن فارسی و حتی ارقام باید راست‌چین رندر شوند تا ستون‌ها
                    // چپ‌نشده‌و خروجی یکپارچه و خوانا باشد.
                    table.Cell().Element(BodyCell).AlignRight().PaddingRight(2).Text(text);
                }
            }
        });
    }

    private static void BuildGenericSummary(IContainer c, IReadOnlyList<string> lines)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Padding(6).Column(col =>
        {
            foreach (var line in lines)
                col.Item().DefaultTextStyle(t => t.FontSize(8.5f).Bold()).Text(line);
        });
    }

    // ─────────────────────────── اجزای مشترک ───────────────────────────

    private static void BuildOfficialHeader(IContainer c, bool isA5, string title)
    {
        // ترتیب RTL: لوگو راست‌ترین و عنوان (راست‌چین) سمت چپِ آن می‌نشیند.
        c.PaddingBottom(6).BorderBottom(2).BorderColor("#0f766e").Row(row =>
        {
            row.RelativeItem().Column(col =>
            {
                col.Item().AlignRight().Text("ترازین — سامانه یکپارچه مدیریت کسب‌وکار")
                    .FontSize(isA5 ? 11 : 13).FontColor("#1a237e").Bold();
                col.Item().PaddingTop(1).AlignRight().Text(title).FontSize(isA5 ? 8 : 9.5f).FontColor("#6b7280");
            });
            row.AutoItem().PaddingLeft(isA5 ? 6 : 8).Element(x => x
                .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                .Background("#0f766e")
                .AlignCenter().AlignMiddle()
                .Text("ت").FontColor(Colors.White).FontSize(isA5 ? 12 : 15).Bold());
        });
    }

    // ─────────────────── موتور چاپ عمومی (قالب‌محور) ───────────────────

    /// <summary>
    /// ساخت PDF از روی قالب چاپ + داده — باندها: هدر اطلاعات شرکت، هدر گزارش
    /// (عنوان + هدر داده)، جدول دیتیل، فوتر گزارش (جمع‌ها)، فوتر صفحه.
    /// چیدمان با رندرر HTML (PrintSheetRenderer) یکسان است.
    /// </summary>
    public byte[] BuildTemplatePdf(PrintTemplateDef tpl, PrintDataModel data)
    {
        var isA5 = tpl.PaperSize == PrintPaperSize.A5;
        var landscape = tpl.Orientation == PrintOrientation.Landscape;
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;
        if (landscape)
            pageSize = isA5 ? PageSizes.A5.Landscape() : PageSizes.A4.Landscape();

        var margin = tpl.MarginMm > 0 ? tpl.MarginMm : 12;

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(margin);
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(tpl.FontSizePt).FontColor("#1f2937"));

                if (tpl.ShowCompanyHeader)
                    page.Header().Element(h => BuildTemplateCompanyHeader(h, tpl, data));

                page.Content().Column(col =>
                {
                    col.Item().Element(c => BuildTemplateReportHeader(c, tpl, data));
                    if (tpl.Columns.Count > 0)
                        col.Item().PaddingTop(4).Element(c => BuildTemplateTable(c, tpl, data));
                    if (tpl.ShowReportFooter)
                        col.Item().PaddingTop(4).Element(c => BuildTemplateReportFooter(c, tpl, data));
                });

                if (tpl.ShowPageFooter)
                    page.Footer().Element(f => BuildOfficialFooter(f, isA5, data.CompanyName ?? "ترازین"));
            });
        }).GeneratePdf();
    }

    private static void BuildTemplateCompanyHeader(IContainer c, PrintTemplateDef tpl, PrintDataModel data)
    {
        var isA5 = tpl.PaperSize == PrintPaperSize.A5;
        c.PaddingBottom(6).BorderBottom(2).BorderColor("#0f766e").Row(row =>
        {
            // ترتیب RTL: نام شرکت راست‌ترین و لوگو سمت چپِ آن.
            row.RelativeItem().Column(col =>
            {
                col.Item().AlignRight().Text(string.IsNullOrWhiteSpace(data.CompanyName)
                    ? "ترازین — سامانه یکپارچه مدیریت کسب‌وکار"
                    : data.CompanyName)
                    .FontSize(isA5 ? 11 : 13).FontColor("#1a237e").Bold();
                if (!string.IsNullOrWhiteSpace(data.CompanyAddress))
                    col.Item().PaddingTop(1).AlignRight().Text($"آدرس: {data.CompanyAddress}")
                        .FontSize(isA5 ? 7 : 8).FontColor("#6b7280");
                // عنوان گزارش فقط یک‌بار (در هدر گزارش) چاپ می‌شود تا با رندرر HTML یکسان باشد.
            });
            row.AutoItem().PaddingLeft(isA5 ? 6 : 8).Element(x => x
                .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                .Background("#0f766e")
                .AlignCenter().AlignMiddle()
                .Text("ت").FontColor(Colors.White).FontSize(isA5 ? 12 : 15).Bold());
        });
    }

    private static void BuildTemplateReportHeader(IContainer c, PrintTemplateDef tpl, PrintDataModel data)
    {
        c.Column(col =>
        {
            var title = string.IsNullOrWhiteSpace(data.Title) ? tpl.ReportTitle : data.Title;
            if (!string.IsNullOrWhiteSpace(title))
                col.Item().AlignRight().Text(title).FontSize(12).Bold().FontColor("#111827");
            var subtitle = string.IsNullOrWhiteSpace(data.Subtitle) ? tpl.ReportSubtitle : data.Subtitle;
            if (!string.IsNullOrWhiteSpace(subtitle))
                col.Item().AlignRight().Text(subtitle).FontSize(9).FontColor("#6b7280");
            if (!string.IsNullOrWhiteSpace(data.RangeText))
                col.Item().AlignRight().Text(data.RangeText).FontSize(8.5f).FontColor("#6b7280");

            var fields = BuildMetaFields(tpl, data);
            if (fields.Count > 0)
            {
                col.Item().PaddingTop(4).Element(meta =>
                {
                    meta.Border(0.8f).BorderColor("#d1d5db").Padding(5).Column(grid =>
                    {
                        for (var i = 0; i < fields.Count; i += 3)
                        {
                            // RTL: اولین فیلد باید راست‌ترین بنشیند؛ Row در QuestPDF LTR است → معکوس.
                            var chunk = fields.Skip(i).Take(3).Reverse().ToList();
                            grid.Item().Row(row =>
                            {
                                foreach (var f in chunk)
                                {
                                    row.RelativeItem().Column(item =>
                                    {
                                        var t = item.Item().AlignRight().Text(MetaText(f));
                                        if (f.Bold)
                                            t = t.Bold();
                                        t.FontSize(8.5f);
                                    });
                                }
                            });
                        }
                    });
                });
            }
        });
    }

    private static List<PrintMetaField> BuildMetaFields(PrintTemplateDef tpl, PrintDataModel data)
    {
        var result = new List<PrintMetaField>();
        var max = Math.Max(tpl.MetaFields.Count, data.MetaFields.Count);
        for (var i = 0; i < max; i++)
        {
            var def = i < tpl.MetaFields.Count ? tpl.MetaFields[i] : new PrintMetaField();
            var value = i < data.MetaFields.Count && data.MetaFields[i].Value is not null
                ? data.MetaFields[i].Value
                : def.Value;
            result.Add(new PrintMetaField
            {
                Label = i < data.MetaFields.Count && !string.IsNullOrWhiteSpace(data.MetaFields[i].Label)
                    ? data.MetaFields[i].Label
                    : def.Label,
                Value = value,
                Bold = i < data.MetaFields.Count ? data.MetaFields[i].Bold : def.Bold
            });
        }
        result.RemoveAll(f => string.IsNullOrWhiteSpace(f.Label) && string.IsNullOrWhiteSpace(f.Value));
        return result;
    }

    private static string MetaText(PrintMetaField f)
        => string.IsNullOrWhiteSpace(f.Label)
            ? f.Value ?? ""
            : $"{f.Label}: {f.Value ?? "—"}";

    private static void BuildTemplateTable(IContainer c, PrintTemplateDef tpl, PrintDataModel data)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // برای هم‌خوانی با HTML (dir=rtl): اولین ستون راست‌ترین می‌شود
            // → ترتیب تعریف ستون‌ها معکوس است.
            var reversed = tpl.Columns.AsEnumerable().Reverse().ToList();
            table.ColumnsDefinition(cols =>
            {
                foreach (var col in reversed)
                    cols.RelativeColumn(Math.Max(col.Width, 20));
            });

            table.Header(h =>
            {
                foreach (var col in reversed)
                    h.Cell().Element(c => ColHeaderCell(c, col, tpl)).Text(col.Title);
            });

            var rowIdx = 0;
            foreach (var row in data.Rows)
            {
                var indent = row.TryGetValue("__indent", out var iv) && iv is int i ? i : 0;
                var bg = row.TryGetValue("__bg", out var bv) ? Convert.ToString(bv, Fa) : null;
                var boldRow = row.TryGetValue("__bold", out var bo) && bo is true;
                var zebra = !string.IsNullOrWhiteSpace(bg) ? null : (rowIdx % 2 == 1 ? "#fafafa" : null);

                foreach (var col in reversed)
                {
                    var isFirst = col == reversed[^1];
                    var value = RowValue(row, col);
                    // هر سلول فقط یک فرزند می‌گیرد → یک زنجیرهٔ واحد تا پایان با .Text
                    // (در QuestPDF نتیجهٔ هر fluent باید دوباره تخصیص شود تا اعمال گردد).
                    table.Cell().Element(inner =>
                    {
                        var x = inner.Padding(2f);
                        // RTL: Start=راست، End=چپ (هماهنگ با CSS رندرر HTML)
                        if (col.Align == PrintAlign.Start)
                            x = x.AlignRight();
                        else if (col.Align == PrintAlign.End)
                            x = x.AlignLeft();
                        else
                            x = x.AlignCenter();
                        var back = bg ?? zebra;
                        if (!string.IsNullOrWhiteSpace(back))
                            x = x.Background(back);
                        if (isFirst && indent > 0)
                            x = x.PaddingLeft((float)(indent * 8));
                        x.Text(t =>
                        {
                            var span = t.Span(value);
                            span.FontSize(tpl.FontSizePt);
                            if (col.Bold || boldRow)
                                span.Bold();
                        });
                    });
                }
                rowIdx++;
            }
        });
    }

    private static string RowValue(PrintRow row, PrintColumnDef col)
    {
        if (!row.TryGetValue(col.Key, out var value) || value is null)
            return "";
        if (value is IFormattable f && !string.IsNullOrWhiteSpace(col.Format))
            return f.ToString(col.Format, Fa);
        if (value is decimal d)
            return string.IsNullOrWhiteSpace(col.Format) ? d.ToString(Fa) : d.ToString(col.Format, Fa);
        if (value is int ii)
            return string.IsNullOrWhiteSpace(col.Format) ? ii.ToString(Fa) : ii.ToString(col.Format, Fa);
        if (value is long ll)
            return string.IsNullOrWhiteSpace(col.Format) ? ll.ToString(Fa) : ll.ToString(col.Format, Fa);
        return Convert.ToString(value, Fa) ?? "";
    }

    private static void BuildTemplateReportFooter(IContainer c, PrintTemplateDef tpl, PrintDataModel data)
    {
        var totals = tpl.Columns.Where(x => x.Total).ToList();
        if (totals.Count == 0 && data.FooterFields.Count == 0)
            return;

        c.Border(0.8f).BorderColor("#d1d5db").Padding(5).Column(col =>
        {
            foreach (var colDef in totals)
            {
                decimal sum = 0;
                foreach (var row in data.Rows)
                {
                    if (row.TryGetValue(colDef.Key, out var v) && v is decimal dd)
                        sum += dd;
                }
                var label = $"جمع {colDef.Title}";
                var value = string.IsNullOrWhiteSpace(colDef.Format)
                    ? sum.ToString(Fa)
                    : sum.ToString(colDef.Format, Fa);
                col.Item().Row(r =>
                {
                    // RTL: لیبل راست و مقدار سمت چپ آن (Row در QuestPDF LTR است → معکوس)
                    r.RelativeItem().AlignLeft().Text(value).Bold();
                    r.RelativeItem().AlignRight().Text(label).Bold();
                });
            }

            foreach (var f in data.FooterFields)
            {
                col.Item().Row(r =>
                {
                    r.RelativeItem().AlignLeft().Text(f.Value ?? "—").Bold();
                    r.RelativeItem().AlignRight().Text(f.Label).Bold();
                });
            }
        });
    }

    private static void BuildOfficialFooter(IContainer c, bool isA5, string rightText)
    {
        c.PaddingTop(4).BorderTop(0.8f).BorderColor("#d1d5db").Row(row =>
        {
            row.RelativeItem().Text(rightText).FontSize(isA5 ? 7 : 8).FontColor("#9ca3af");
            row.RelativeItem().AlignRight().Text(t =>
            {
                t.Span("صفحه ").FontSize(isA5 ? 7 : 8).FontColor("#9ca3af");
                t.CurrentPageNumber().FontSize(isA5 ? 7 : 8).FontColor("#9ca3af");
                t.Span(" از ").FontSize(isA5 ? 7 : 8).FontColor("#9ca3af");
                t.TotalPages().FontSize(isA5 ? 7 : 8).FontColor("#9ca3af");
            });
        });
    }

    // سلول‌های جدول برای زبان فارسی باید راست‌چین (RTL) رندر شوند؛ وگرنه
    // خروجی PDF چپ‌چین و به‌هم‌ریخته می‌شود. ستون‌های عددی هم راست‌چین‌اند
    // (طبق عرف گزارش‌های فارسی) بنابراین همین راست‌چینی سراسری کافی است.
    private static IContainer HeaderCell(IContainer c)
        => c.Background("#f3f4f6").BorderBottom(1).BorderColor("#d1d5db").Padding(4)
            .AlignRight().DefaultTextStyle(t => t.FontSize(8.5f));

    /// <summary>
    /// هدر ستون قالب‌محور — ترازِ هر ستون همانند رندرر HTML (RTL: Start=راست، End=چپ)
    /// اعمال می‌شود تا چاپ مرورگر و PDF یکسان باشند.
    /// </summary>
    private static IContainer ColHeaderCell(IContainer c, PrintColumnDef col, PrintTemplateDef tpl)
    {
        var x = c.Background("#f3f4f6").Border(0.4f).BorderColor("#d1d5db").Padding(2.5f);
        x = col.Align switch
        {
            PrintAlign.End => x.AlignLeft(),
            PrintAlign.Center => x.AlignCenter(),
            _ => x.AlignRight()
        };
        return x.DefaultTextStyle(t => t.FontSize(tpl.FontSizePt).Bold());
    }

    private static IContainer BodyCell(IContainer c)
        => c.BorderBottom(0.5f).BorderColor("#e5e7eb").Padding(4)
            .AlignRight().DefaultTextStyle(t => t.FontSize(8.5f));

    private static string DueLabel(int days) => days switch
    {
        0 => "امروز",
        _ => days > 0 ? $"{days} روز مانده" : $"{Math.Abs(days)} روز گذشته"
    };

    private static string StatusLabel(string status) => status switch
    {
        "Pending" => "در انتظار",
        "Collecting" => "در جریان وصول",
        _ => status
    };

    private static string AlertLabel(string level) => level switch
    {
        "Overdue" => "سررسیدشده",
        "DueSoon" => "سررسید نزدیک",
        _ => "در مهلت"
    };

    private static string SourceLabel(string? source) => source switch
    {
        null => "دستی",
        var s when s.StartsWith("GoldInvoice:") => "فاکتور طلافروشی",
        var s when s.StartsWith("Cheque:") => "وصول چک",
        _ => source ?? ""
    };
}
