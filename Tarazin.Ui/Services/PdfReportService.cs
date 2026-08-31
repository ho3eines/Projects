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
        // ثبت متمرکز فونت Vazirmatn (QuestPDF) — idempotent است و
        // اگر AddTarazinUiServices زودتر صدا زده باشد، دوباره کاری نمی‌کند.
        VazirmatnFontRegistrar.Register();
    }

    public PdfReportService()
    {
        // سازندهٔ عمومی برای DI — فونت‌ها در static ctor یک‌بار ثبت می‌شوند.
    }

    // ─────────────────────────── فاکتور طلا ───────────────────────────

    /// <summary>ساخت PDF فاکتور خرید/فروش طلا (A4 یا A5 پرتره).</summary>
    public byte[] BuildInvoicePdf(GoldInvoicePrintModel model, string paperSize = "A4")
    {
        var isA5 = paperSize.StartsWith("A5", StringComparison.OrdinalIgnoreCase);
        var landscape = paperSize.IndexOf("L", StringComparison.OrdinalIgnoreCase) >= 0;
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;
        if (landscape)
            pageSize = isA5 ? PageSizes.A5.Landscape() : PageSizes.A4.Landscape();

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 20 : 28);
                // کل سند راست‌به‌چپ: متن‌ها RTL و ترتیب Row/Table معکوس می‌شود
                // (اولین آیتم = راست‌ترین) — دیگر نیازی به شبیه‌سازی دستی RTL نیست.
                page.ContentFromRightToLeft();
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
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون = راست‌ترین.
            // «شماره فاکتور» راست‌ترین (اولینِ خوانده‌شده) و «سند حسابداری» چپ‌ترین.
            row.RelativeItem().Column(meta =>
            {
                meta.Item().Text($"شماره فاکتور: {model.InvoiceNumber}").Bold();
                meta.Item().Text($"تاریخ: {model.InvoiceDate.ToString("yyyy/MM/dd", Fa)}");
            });
            row.RelativeItem().Column(meta =>
            {
                meta.Item().Text($"مشتری: {model.PartyName}").Bold();
                if (!string.IsNullOrWhiteSpace(model.DetailCode))
                    meta.Item().Text($"کد تفصیلی: {model.DetailCode}");
            });
            row.RelativeItem().Column(meta =>
            {
                meta.Item().Text($"سند حسابداری: {model.DocumentId:N0}").Bold();
                meta.Item().Text($"مالیات: ٪{model.TaxPct:0.#}");
            });
        });
    }

    private static void BuildInvoiceLines(IContainer c, GoldInvoicePrintModel model)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون تعریف‌شده = راست‌ترین.
            // «ردیف» باید راست‌ترین و «جمع ردیف» چپ‌ترین باشد.
            table.ColumnsDefinition(cols =>
            {
                cols.ConstantColumn(24);   // ردیف (راست‌ترین)
                cols.RelativeColumn(2);    // نوع
                cols.RelativeColumn(4);    // کالا / ارز
                cols.RelativeColumn(2);    // مقدار
                cols.RelativeColumn(3);    // نرخ / قیمت
                cols.RelativeColumn(2.5f); // اجرت
                cols.RelativeColumn(2.5f); // سود
                cols.RelativeColumn(3);    // جمع ردیف (چپ‌ترین)
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("ردیف").Bold();
                h.Cell().Element(HeaderCell).Text("نوع").Bold();
                h.Cell().Element(HeaderCell).Text("کالا / ارز").Bold();
                h.Cell().Element(HeaderCell).Text("مقدار").Bold();
                h.Cell().Element(HeaderCell).Text("نرخ / قیمت").Bold();
                h.Cell().Element(HeaderCell).Text("اجرت").Bold();
                h.Cell().Element(HeaderCell).Text("سود").Bold();
                h.Cell().Element(HeaderCell).Text("جمع ردیف").Bold();
            });

            var i = 1;
            foreach (var line in model.Lines)
            {
                var index = i++;
                table.Cell().Element(BodyCell).Text(index.ToString());
                table.Cell().Element(BodyCell).Text(line.RowType == "Gold" ? "طلا" : "ارز");
                table.Cell().Element(BodyCell).Text(line.Title);
                table.Cell().Element(BodyCell).Text(FormatQty(line));
                table.Cell().Element(BodyCell).AlignRight().Text(line.RowType == "Gold"
                    ? line.Price.ToString("N0", Fa)
                    : line.ResolvedRate.ToString("N0", Fa));
                table.Cell().Element(BodyCell).AlignRight().Text(line.Workmanship.ToString("N0", Fa));
                table.Cell().Element(BodyCell).AlignRight().Text(line.Profit.ToString("N0", Fa));
                table.Cell().Element(BodyCell).AlignRight().Text(LineTotal(line).ToString("N0", Fa));
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
            // RTL: کارت جمع‌ها راست‌ترین (اولین آیتم).
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
            row.RelativeItem();
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
            // RTL (ContentFromRightToLeft): برچسب «روش تسویه» راست‌ترین (اولین آیتم).
            row.RelativeItem().AlignRight().Text("روش تسویه").Bold();
            row.RelativeItem().AlignRight().Text(string.Join("   |   ", parts));
        });
    }

    // ─────────────────────────── سند حسابداری ───────────────────────────

    /// <summary>
    /// ساخت PDF سند حسابداری (ساده یا پیشرفته — A4/A5 پرتره).
    /// چیدمان با رندرر HTML دیالوگ چاپ سند یکسان است: هدر رسمی (لوگو/نام/آدرس + QR)،
    /// جدول دیتیل (ساده: ردیف‌ها؛ پیشرفته: کل → معین → تفصیل تودرتو با جمع هر سطح).
    /// </summary>
    public byte[] BuildDocumentPdf(AccountingDocumentPrintModel model, string paperSize = "A4")
    {
        // token «A5» = پیش‌فرض پرتره؛ «A5L»/«A5-L» = landscape (مثل گزارش چک).
        var isA5 = paperSize.StartsWith("A5", StringComparison.OrdinalIgnoreCase);
        var landscape = paperSize.IndexOf("L", StringComparison.OrdinalIgnoreCase) >= 0;
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;
        if (landscape)
            pageSize = isA5 ? PageSizes.A5.Landscape() : PageSizes.A4.Landscape();

        var qr = (!string.IsNullOrWhiteSpace(model.QrBaseUrl) || true)
            ? BuildQrPng(string.IsNullOrWhiteSpace(model.QrBaseUrl)
                ? $"tarazin:doc:{model.DocumentId}"
                : $"{model.QrBaseUrl.TrimEnd('/')}/doc/{model.DocumentId}")
            : null;

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 18 : 22);
                // کل سند راست‌به‌چپ (متن‌ها RTL + ترتیب Row/Table معکوس).
                page.ContentFromRightToLeft();
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(9).FontColor("#1f2937"));

                page.Header().Element(h => BuildDocumentCompanyHeader(h, isA5, model, qr));

                page.Content().Column(col =>
                {
                    col.Item().Element(c => BuildDocumentMeta(c, model));
                    col.Item().PaddingTop(6).Element(c =>
                    {
                        if (model.Advanced)
                            BuildDocumentAdvancedTable(c, model);
                        else
                            BuildDocumentTable(c, model);
                    });
                    col.Item().PaddingTop(6).Element(c => BuildDocumentTotals(c, model));
                });

                page.Footer().Element(f => BuildOfficialFooter(f, isA5, $"سند {model.DocumentNumber}"));
            });
        }).GeneratePdf();
    }

    /// <summary>هدر رسمی سند — لوگو/نام/آدرس شرکت (از تنظیمات) + QRCode پیگیری، هم‌راست با رندرر HTML.</summary>
    private static void BuildDocumentCompanyHeader(IContainer c, bool isA5, AccountingDocumentPrintModel model, byte[]? qr)
    {
        c.PaddingBottom(6).BorderBottom(2).BorderColor("#0f766e").Row(row =>
        {
            // کل سند ContentFromRightToLeft است؛ پس اولین آیتم = راست‌ترین:
            // لوگو راست‌ترین، نام/عنوان راست‌چین وسط، QR چپ‌ترین — مثل هدر HTML.
            // لوگو — راست‌ترین عنصر هدر (RTL)
            row.AutoItem().Element(x =>
            {
                var logo = TryLoadImage(model.LogoPath);
                var size = isA5 ? 20 : 26;
                if (logo is not null)
                    x.Width(size).Height(size).Image(logo);
                else
                    x.Width(size).Height(size).Background("#0f766e").AlignCenter().AlignMiddle()
                        .Text("ت").FontColor(Colors.White).FontSize(isA5 ? 12 : 15).Bold();
            });

            row.RelativeItem().PaddingLeft(isA5 ? 6 : 8).Column(col =>
            {
                col.Item().AlignRight().Text(string.IsNullOrWhiteSpace(model.BrandName)
                        ? "ترازین — سامانه یکپارچه مدیریت کسب‌وکار"
                        : model.BrandName)
                    .FontSize(isA5 ? 11 : 13).FontColor("#1a237e").Bold();
                col.Item().PaddingTop(1).AlignRight()
                    .Text($"سند حسابداری {TypeDocLabel(model.DocumentType)} — شماره {model.DocumentNumber}")
                    .FontSize(isA5 ? 8 : 9.5f).FontColor("#6b7280");
            });

            if (qr is not null)
                row.AutoItem().Element(x => x
                    .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                    .Image(qr));
        });
    }

    /// <summary>تبدیل مسیر/data-URL لوگو به بایت‌های تصویر برای QuestPDF — null اگر قابل خواندن نباشد.</summary>
    private static byte[]? TryLoadImage(string? logoPath)
    {
        if (string.IsNullOrWhiteSpace(logoPath)) return null;
        try
        {
            if (logoPath.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
            {
                var comma = logoPath.IndexOf(',');
                if (comma < 0) return null;
                return Convert.FromBase64String(logoPath[(comma + 1)..]);
            }
            if (File.Exists(logoPath))
                return File.ReadAllBytes(logoPath);
        }
        catch { /* لوگوی نامعتبر → fallback آواتار */ }
        return null;
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

    /// <summary>جدول سادهٔ سند — ستون‌ها هم‌ارز رندرر HTML: کد، عنوان، شرح، بدهکار، بستانکار.</summary>
    private static void BuildDocumentTable(IContainer c, AccountingDocumentPrintModel model)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون = راست‌ترین.
            // «کد حساب» باید راست‌ترین و «بستانکار» چپ‌ترین باشد (مثل HTML).
            table.ColumnsDefinition(cols =>
            {
                cols.RelativeColumn(1.4f); // کد حساب (راست‌ترین)
                cols.RelativeColumn(3);    // عنوان حساب
                cols.RelativeColumn(2.4f); // شرح ردیف
                cols.RelativeColumn(1.6f); // بدهکار
                cols.RelativeColumn(1.6f); // بستانکار (چپ‌ترین)
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("کد حساب").Bold();
                h.Cell().Element(HeaderCell).Text("عنوان حساب").Bold();
                h.Cell().Element(HeaderCell).Text("شرح ردیف").Bold();
                h.Cell().Element(HeaderCell).Text("بدهکار").Bold();
                h.Cell().Element(HeaderCell).Text("بستانکار").Bold();
            });

            foreach (var line in model.Lines)
            {
                table.Cell().Element(BodyCell).Text(line.AccountCode);
                table.Cell().Element(BodyCell).Text(line.Title ?? "");
                table.Cell().Element(BodyCell).Text(line.Description ?? "");
                table.Cell().Element(BodyCell).AlignRight().Text(line.Debit > 0 ? line.Debit.ToString("N0", Fa) : "");
                table.Cell().Element(BodyCell).AlignRight().Text(line.Credit > 0 ? line.Credit.ToString("N0", Fa) : "");
            }
        });
    }

    /// <summary>
    /// جدول پیشرفتهٔ سند — سلسله‌مراتب تودرتو: کل (۲ رقم) → معین (۵ رقم) → تفصیل (ریز ردیف).
    /// هر کل زیرِ خودش معین‌هایش را و هر معین زیر خودش تفصیل‌ها را نشان می‌دهد؛
    /// جمع هر سطح در ستون‌های بدهکار/بستانکار همان ردیف نمایش داده می‌شود (هم‌ارز HTML).
    /// </summary>
    private static void BuildDocumentAdvancedTable(IContainer c, AccountingDocumentPrintModel model)
    {
        var rows = BuildAdvancedDocRows(model);
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون = راست‌ترین.
            // «کد» باید راست‌ترین و «بستانکار» چپ‌ترین باشد (مثل HTML).
            table.ColumnsDefinition(cols =>
            {
                cols.RelativeColumn(1.3f); // کد (راست‌ترین)
                cols.RelativeColumn(4.5f); // عنوان حساب
                cols.RelativeColumn(0.8f); // تعداد
                cols.RelativeColumn(1.4f); // بدهکار
                cols.RelativeColumn(1.4f); // بستانکار (چپ‌ترین)
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("کد").Bold();
                h.Cell().Element(HeaderCell).Text("عنوان حساب").Bold();
                h.Cell().Element(HeaderCell).Text("تعداد").Bold();
                h.Cell().Element(HeaderCell).Text("بدهکار").Bold();
                h.Cell().Element(HeaderCell).Text("بستانکار").Bold();
            });

            foreach (var r in rows)
            {
                var bg = r.Level switch
                {
                    0 => "#eef2ff",
                    1 => "#f8fafc",
                    _ => ""
                };
                var bold = r.Level == 0;

                // QuestPDF به رشتهٔ خالی به‌عنوان رنگ اعتراض می‌کند؛ پس فقط وقتی bg پر است اعمالش کن.
                // (نکته: نباید دو child روی یک container گذاشت — پس زنجیره می‌سازیم.)
                static IContainer StyleCell(IContainer cell, string color)
                    => color.Length > 0 ? BodyCell(cell).Background(color) : BodyCell(cell);

                table.Cell().Element(cell => StyleCell(cell, bg))
                    .Text(r.Code);
                table.Cell().Element(cell => StyleCell(cell, bg))
                    .PaddingLeft(r.Level * 10).Text(t =>
                    {
                        t.Span(r.Title);
                        if (r.Level == 0) t.Span("  (کل)").FontColor("#4f46e5");
                        else if (r.Level == 1) t.Span("  (معین)").FontColor("#0d9488");
                    });
                table.Cell().Element(cell => StyleCell(cell, bg))
                    .AlignCenter().Text(r.LineCount > 0 ? r.LineCount.ToString() : "—");
                table.Cell().Element(cell => StyleCell(cell, bg))
                    .AlignRight().Text(r.Debit > 0 ? r.Debit.ToString("N0", Fa) : "");
                table.Cell().Element(cell => StyleCell(cell, bg))
                    .AlignRight().Text(r.Credit > 0 ? r.Credit.ToString("N0", Fa) : "");
            }
        });
    }

    /// <summary>ساخت ردیف‌های تودرتوی چاپ پیشرفته از رول‌آپ مدل — ترتیب کل ← معین ← تفصیل.</summary>
    private static List<DocPdfRow> BuildAdvancedDocRows(AccountingDocumentPrintModel model)
    {
        var result = new List<DocPdfRow>();
        var kols = model.KolRows.Count > 0
            ? model.KolRows
            : model.Lines
                .GroupBy(l => l.AccountCode.Length >= 2 ? l.AccountCode[..2] : l.AccountCode)
                .Select(g => new AccountRollupRow
                {
                    Code = g.Key,
                    Title = g.First().Title,
                    Debit = g.Sum(x => x.Debit),
                    Credit = g.Sum(x => x.Credit),
                    LineCount = g.Count()
                }).ToList();

        foreach (var kol in kols.OrderBy(k => k.Code, StringComparer.Ordinal))
        {
            var moeins = (model.MoeinRows.Count > 0 ? model.MoeinRows : new List<AccountRollupRow>())
                .Where(m => m.Code.Length >= 2 && m.Code.StartsWith(kol.Code, StringComparison.Ordinal))
                .OrderBy(m => m.Code, StringComparer.Ordinal).ToList();

            // اگر معین‌ها از رول‌آپ نیامدند، از روی ردیف‌ها تجمیع کن
            if (moeins.Count == 0)
            {
                moeins = model.Lines
                    .Where(l => l.AccountCode.StartsWith(kol.Code, StringComparison.Ordinal))
                    .GroupBy(l => l.AccountCode.Length >= 5 ? l.AccountCode[..5] : l.AccountCode)
                    .Select(g => new AccountRollupRow
                    {
                        Code = g.Key,
                        Title = g.First().Title,
                        Debit = g.Sum(x => x.Debit),
                        Credit = g.Sum(x => x.Credit),
                        LineCount = g.Count()
                    }).OrderBy(m => m.Code, StringComparer.Ordinal).ToList();
            }

            decimal kolDebit = 0, kolCredit = 0;
            int kolCount = 0;
            var moeinBlock = new List<DocPdfRow>();

            foreach (var moein in moeins)
            {
                var moeinLines = model.Lines
                    .Where(l => l.AccountCode.StartsWith(moein.Code, StringComparison.Ordinal))
                    .OrderBy(l => l.AccountCode, StringComparer.Ordinal).ToList();
                var mDebit = moeinLines.Sum(l => l.Debit);
                var mCredit = moeinLines.Sum(l => l.Credit);
                kolDebit += mDebit; kolCredit += mCredit; kolCount += moeinLines.Count;

                moeinBlock.Add(new DocPdfRow
                {
                    Level = 1, Code = moein.Code, Title = moein.Title,
                    Debit = mDebit, Credit = mCredit, LineCount = moeinLines.Count
                });

                foreach (var line in moeinLines)
                {
                    moeinBlock.Add(new DocPdfRow
                    {
                        Level = 2, Code = line.AccountCode,
                        Title = string.IsNullOrWhiteSpace(line.Description)
                            ? line.Title
                            : $"{line.Title} — {line.Description}",
                        Debit = line.Debit, Credit = line.Credit, LineCount = 0
                    });
                }
            }

            result.Add(new DocPdfRow
            {
                Level = 0, Code = kol.Code, Title = kol.Title,
                Debit = kolDebit, Credit = kolCredit, LineCount = kolCount
            });
            result.AddRange(moeinBlock);
        }
        return result;
    }

    /// <summary>ردیف چاپ پیشرفتهٔ PDF — سطح سلسله‌مراتب (۰=کل، ۱=معین، ۲=تفصیل).</summary>
    private sealed class DocPdfRow
    {
        public int Level { get; set; }
        public string Code { get; set; } = "";
        public string Title { get; set; } = "";
        public int LineCount { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
    }

    private static string LineLabel(DocumentLineRow line)
        => string.IsNullOrWhiteSpace(line.Description) ? line.Title : $"{line.Title} — {line.Description}";

    private static void BuildDocumentTotals(IContainer c, AccountingDocumentPrintModel model)
    {
        c.PaddingTop(2).Row(row =>
        {
            // RTL: کارت جمع‌ها راست‌ترین (اولین آیتم).
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
            row.RelativeItem();
        });
    }

    /// <summary>
    /// تعداد صفحهٔ PDF سند حسابداری برای اندازهٔ داده‌شده — بدون ذخیرهٔ فایل.
    /// با همان بایت‌های BuildDocumentPdf ساخته و سپس صفحات از روی آبجکت‌های
    /// /Type /Page شمارش می‌شود تا کاربر پیش از دانلود بداند چندصفحه خواهد شد.
    /// </summary>
    public int BuildDocumentPdfPageCount(AccountingDocumentPrintModel model, string paperSize = "A4")
    {
        try
        {
            var bytes = BuildDocumentPdf(model, paperSize);
            return CountPdfPages(bytes);
        }
        catch
        {
            return 0;
        }
    }

    /// <summary>شمارش صفحات یک بایت‌آرایهٔ PDF — آبجکت‌های /Type /Page (نه والد /Type /Pages).</summary>
    public static int CountPdfPages(byte[] pdf)
    {
        if (pdf is null || pdf.Length == 0) return 0;
        var s = System.Text.Encoding.Latin1.GetString(pdf);
        var count = 0;
        var idx = 0;
        var len = s.Length;
        while ((idx = s.IndexOf("/Type", idx, StringComparison.Ordinal)) >= 0)
        {
            var rest = s.Substring(idx, Math.Min(24, len - idx));
            if (System.Text.RegularExpressions.Regex.IsMatch(rest, @"^/Type\s*/Page\s"))
                count++;
            idx += 6;
        }
        return count;
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
        // گزارش چک‌ها همیشه افقی است؛ «A5L»=A5 افقی، بقیه پیش‌فرض A4 افقی.
        var isA5 = paperSize.StartsWith("A5", StringComparison.OrdinalIgnoreCase);
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
                // کل سند راست‌به‌چپ (متن‌ها RTL + ترتیب Row/Table معکوس).
                page.ContentFromRightToLeft();
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
            // RTL (ContentFromRightToLeft): «چک‌های باز» راست‌ترین کارت (اولین آیتم).
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("چک‌های باز").FontColor("#6b7280");
                x.Item().Text(total.ToString("N0", Fa)).FontSize(14).Bold();
            });
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("سررسیدشده").FontColor("#dc2626");
                x.Item().Text(overdue.ToString("N0", Fa)).FontSize(14).Bold().FontColor("#dc2626");
            });
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("سررسید نزدیک").FontColor("#d97706");
                x.Item().Text(dueSoon.ToString("N0", Fa)).FontSize(14).Bold().FontColor("#d97706");
            });
            row.RelativeItem().Column(x =>
            {
                x.Item().Text("جمع سررسیدشده").FontColor("#dc2626");
                x.Item().Text(overdueAmount.ToString("N0", Fa) + " ریال").FontSize(14).Bold().FontColor("#dc2626");
            });
        });
    }

    private static void BuildChequeTable(IContainer c, List<ChequeDueRow> rows)
    {
        c.Border(0.8f).BorderColor("#d1d5db").Table(table =>
        {
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون تعریف‌شده = راست‌ترین.
            // «شماره چک» باید راست‌ترین و «منبع» چپ‌ترین باشد.
            table.ColumnsDefinition(cols =>
            {
                cols.RelativeColumn(2);    // شماره (راست‌ترین)
                cols.RelativeColumn(2);    // بانک
                cols.RelativeColumn(1.2f); // جهت
                cols.RelativeColumn(2);    // مبلغ
                cols.RelativeColumn(1.8f); // سررسید
                cols.RelativeColumn(1.8f); // مانده تا سررسید
                cols.RelativeColumn(1.5f); // وضعیت
                cols.RelativeColumn(1.5f); // هشدار
                cols.RelativeColumn(1.8f); // منبع (چپ‌ترین)
            });

            table.Header(h =>
            {
                h.Cell().Element(HeaderCell).Text("شماره چک").Bold();
                h.Cell().Element(HeaderCell).Text("بانک").Bold();
                h.Cell().Element(HeaderCell).Text("جهت").Bold();
                h.Cell().Element(HeaderCell).Text("مبلغ").Bold();
                h.Cell().Element(HeaderCell).Text("سررسید").Bold();
                h.Cell().Element(HeaderCell).Text("مانده تا سررسید").Bold();
                h.Cell().Element(HeaderCell).Text("وضعیت").Bold();
                h.Cell().Element(HeaderCell).Text("هشدار").Bold();
                h.Cell().Element(HeaderCell).Text("منبع").Bold();
            });

            foreach (var chq in rows)
            {
                var alertColor = chq.AlertLevel switch
                {
                    "Overdue" => "#dc2626",
                    "DueSoon" => "#d97706",
                    _ => "#059669"
                };

                table.Cell().Element(BodyCell).Text(chq.ChequeNumber);
                table.Cell().Element(BodyCell).Text(chq.BankName);
                table.Cell().Element(BodyCell).Text(chq.Direction == "In" ? "دریافتی" : "پرداختی");
                table.Cell().Element(BodyCell).AlignRight().Text(chq.Amount.ToString("N0", Fa));
                table.Cell().Element(BodyCell).Text(chq.DueDate?.ToString("yyyy/MM/dd", Fa) ?? "—");
                table.Cell().Element(BodyCell).Text(DueLabel(chq.DaysToDue));
                table.Cell().Element(BodyCell).Text(StatusLabel(chq.Status));
                table.Cell().Element(BodyCell).Text(AlertLabel(chq.AlertLevel)).FontColor(alertColor).Bold();
                table.Cell().Element(BodyCell).Text(SourceLabel(chq.SourceReference));
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
        string paperSize = "A4",
        string? companyName = null,
        string? companyAddress = null,
        string? qrPayload = null)
    {
        var isA5 = paperSize.StartsWith("A5", StringComparison.OrdinalIgnoreCase);
        // «A5L»/اندازهٔ با پسوند L = افقی اجباری؛ وگرنه ستون‌های زیاد خودکار افقی می‌شوند.
        var forceLandscape = paperSize.IndexOf("L", StringComparison.OrdinalIgnoreCase) >= 0;
        var landscape = forceLandscape || columns.Count > 6;
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;
        if (landscape)
            pageSize = pageSize.Landscape();

        // QR پیگیری گزارش — مثل بقیهٔ چاپ‌ها (فاکتور/سند/قالب). اگر payload بیاید
        // و قابل ساخت باشد، در هدر رسمی درج می‌شود؛ وگرنه باند خاموش می‌ماند.
        var qrPng = string.IsNullOrWhiteSpace(qrPayload) ? null : BuildQrPng(qrPayload!);

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(isA5 ? 18 : 22);
                // کل سند راست‌به‌چپ (متن‌ها RTL + ترتیب Row/Table معکوس).
                page.ContentFromRightToLeft();
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(8.5f).FontColor("#1f2937"));

                page.Header().Element(h => BuildOfficialHeader(h, isA5, title, companyName, companyAddress, qrPng));

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
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون = راست‌ترین،
            // پس ستون‌ها و سلول‌ها به ترتیب طبیعی (بدون Reverse) پیمایش می‌شوند.
            table.ColumnsDefinition(cols =>
            {
                for (var i = 0; i < columns.Count; i++)
                    cols.RelativeColumn(1);
            });

            table.Header(h =>
            {
                for (var i = 0; i < columns.Count; i++)
                    // هدر فارسی همیشه راست‌چین (RTL).
                    h.Cell().Element(HeaderCell).AlignRight().Text(columns[i].Header).Bold();
            });

            foreach (var row in rows)
            {
                for (var i = 0; i < columns.Count; i++)
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

    private static void BuildOfficialHeader(IContainer c, bool isA5, string title,
        string? companyName = null, string? companyAddress = null, byte[]? qrPng = null)
    {
        // کل سند ContentFromRightToLeft است؛ پس اولین آیتم = راست‌ترین:
        // لوگو راست‌ترین، نام/عنوان راست‌چین وسط، QR چپ‌ترین — مثل هدر HTML و هدر سند.
        c.PaddingBottom(6).BorderBottom(2).BorderColor("#0f766e").Row(row =>
        {
            // لوگو — راست‌ترین عنصر هدر (RTL)
            row.AutoItem().PaddingLeft(isA5 ? 6 : 8).Element(x => x
                .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                .Background("#0f766e")
                .AlignCenter().AlignMiddle()
                .Text("ت").FontColor(Colors.White).FontSize(isA5 ? 12 : 15).Bold());

            row.RelativeItem().PaddingLeft(isA5 ? 6 : 8).Column(col =>
            {
                col.Item().AlignRight().Text(string.IsNullOrWhiteSpace(companyName)
                        ? "ترازین — سامانه یکپارچه مدیریت کسب‌وکار"
                        : companyName!)
                    .FontSize(isA5 ? 11 : 13).FontColor("#1a237e").Bold();
                if (!string.IsNullOrWhiteSpace(companyAddress))
                    col.Item().PaddingTop(1).AlignRight().Text($"آدرس: {companyAddress}")
                        .FontSize(isA5 ? 7 : 8).FontColor("#6b7280");
                col.Item().PaddingTop(1).AlignRight().Text(title).FontSize(isA5 ? 8 : 9.5f).FontColor("#6b7280");
            });

            if (qrPng is not null)
                row.AutoItem().Element(x => x
                    .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                    .Image(qrPng));
        });
    }

    // ─────────────────── موتور چاپ عمومی (قالب‌محور) ───────────────────

    /// <summary>
    /// ساخت PDF از روی قالب چاپ + داده — باندها: هدر اطلاعات شرکت، هدر گزارش
    /// (عنوان + هدر داده)، جدول دیتیل، فوتر گزارش (جمع‌ها)، فوتر صفحه.
    /// چیدمان با رندرر HTML (PrintSheetRenderer) یکسان است.
    /// </summary>
    public byte[] BuildTemplatePdf(PrintTemplateDef tpl, PrintDataModel data, string? paperSizeOverride = null)
    {
        // override ران‌تایم (A4/A5/A5L) — مثل بقیهٔ چاپ‌ها؛ اگر خالی بود از تنظیمات قالب.
        var size = paperSizeOverride;
        var isA5 = string.IsNullOrEmpty(size)
            ? tpl.PaperSize == PrintPaperSize.A5
            : size.StartsWith("A5", StringComparison.OrdinalIgnoreCase);
        var landscape = string.IsNullOrEmpty(size)
            ? tpl.Orientation == PrintOrientation.Landscape
            : size.IndexOf("L", StringComparison.OrdinalIgnoreCase) >= 0;
        var pageSize = isA5 ? PageSizes.A5 : PageSizes.A4;
        if (landscape)
            pageSize = isA5 ? PageSizes.A5.Landscape() : PageSizes.A4.Landscape();

        var margin = tpl.MarginMm > 0 ? tpl.MarginMm : 12;

        // QR مستقل (هدر شرکت خاموش ولی QR روشن) — گوشهٔ بالای راست، مثل رندرر HTML
        var standaloneQr = (!tpl.ShowCompanyHeader && tpl.QrEnabled && data.QrEnabled
                            && !string.IsNullOrWhiteSpace(data.QrPayload))
            ? BuildQrPng(data.QrPayload!)
            : null;

        return Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(pageSize);
                page.Margin(margin);
                // کل سند راست‌به‌چپ (متن‌ها RTL + ترتیب Row/Table معکوس).
                page.ContentFromRightToLeft();
                page.DefaultTextStyle(t => t.FontFamily(FontFamily).FontSize(tpl.FontSizePt).FontColor("#1f2937"));

                if (tpl.ShowCompanyHeader)
                    page.Header().Element(h => BuildTemplateCompanyHeader(h, tpl, data));

                page.Content().Column(col =>
                {
                    // QR مستقل بدون هدر شرکت — دقیقاً مثل .tpl-standalone-qr در HTML
                    if (standaloneQr is not null)
                        col.Item().PaddingBottom(4).Element(c => BuildStandaloneQr(c, standaloneQr));

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

    /// <summary>باند QR مستقل (بدون هدر شرکت) — گوشهٔ بالای راست برگه، هم‌راست با رندرر HTML.</summary>
    private static void BuildStandaloneQr(IContainer c, byte[] qrPng)
    {
        c.Row(row =>
        {
            // RTL (ContentFromRightToLeft): QR راست‌ترین (اولین آیتم) — گوشهٔ بالای راست.
            row.AutoItem().Element(x => x
                .Width(26).Height(26)
                .Image(qrPng));
            row.RelativeItem();
        });
    }

    /// <summary>
    /// تولید PNGِ QRCode از payload با QRCoder.Core — خالص و بدون وابستگی به
    /// System.Drawing، پس روی همهٔ پلتفرم‌ها (وب، اندروید/iOS/ویندوز) کار می‌کند.
    /// </summary>
    private static byte[]? BuildQrPng(string payload)
    {
        try
        {
            using var generator = new QRCoder.QRCodeGenerator();
            var qrData = generator.CreateQrCode(payload, QRCoder.QRCodeGenerator.ECCLevel.M);
            using var qr = new QRCoder.PngByteQRCode(qrData);
            return qr.GetGraphic(4);
        }
        catch
        {
            return null; // اگر QR ساخته نشد، باند خاموش می‌ماند (مثل fallback در HTML)
        }
    }

    private static void BuildTemplateCompanyHeader(IContainer c, PrintTemplateDef tpl, PrintDataModel data)
    {
        var isA5 = tpl.PaperSize == PrintPaperSize.A5;
        c.PaddingBottom(6).BorderBottom(2).BorderColor("#0f766e").Row(row =>
        {
            // کل سند ContentFromRightToLeft است؛ پس اولین آیتم = راست‌ترین:
            // لوگو راست‌ترین، نام/آدرس شرکت راست‌چین وسط، QR چپ‌ترین — مثل هدر HTML.
            // لوگو — راست‌ترین عنصر هدر (RTL)
            row.AutoItem().PaddingLeft(isA5 ? 6 : 8).Element(x => x
                .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                .Background("#0f766e")
                .AlignCenter().AlignMiddle()
                .Text("ت").FontColor(Colors.White).FontSize(isA5 ? 12 : 15).Bold());

            row.RelativeItem().PaddingLeft(isA5 ? 6 : 8).Column(col =>
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

            if (tpl.QrEnabled && data.QrEnabled && !string.IsNullOrWhiteSpace(data.QrPayload))
            {
                var qr = BuildQrPng(data.QrPayload!);
                if (qr is not null)
                    row.AutoItem().Element(x => x
                        .Width(isA5 ? 20 : 26).Height(isA5 ? 20 : 26)
                        .Image(qr));
            }
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
                            // RTL (ContentFromRightToLeft): اولین فیلد راست‌ترین → ترتیب طبیعی.
                            var chunk = fields.Skip(i).Take(3).ToList();
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
            // کل سند RTL است (ContentFromRightToLeft): اولین ستون = راست‌ترین،
            // پس ستون‌ها به ترتیب طبیعی (بدون Reverse) تعریف می‌شوند.
            table.ColumnsDefinition(cols =>
            {
                foreach (var col in tpl.Columns)
                    cols.RelativeColumn(Math.Max(col.Width, 20));
            });

            table.Header(h =>
            {
                foreach (var col in tpl.Columns)
                    h.Cell().Element(c => ColHeaderCell(c, col, tpl)).Text(col.Title);
            });

            var rowIdx = 0;
            foreach (var row in data.Rows)
            {
                var indent = row.TryGetValue("__indent", out var iv) && iv is int i ? i : 0;
                var bg = row.TryGetValue("__bg", out var bv) ? Convert.ToString(bv, Fa) : null;
                var boldRow = row.TryGetValue("__bold", out var bo) && bo is true;
                var zebra = !string.IsNullOrWhiteSpace(bg) ? null : (rowIdx % 2 == 1 ? "#fafafa" : null);

                foreach (var col in tpl.Columns)
                {
                    var isFirst = col == tpl.Columns[0];
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
                    // RTL (ContentFromRightToLeft): لیبل راست‌ترین (اولین آیتم) و مقدار سمت چپ.
                    r.RelativeItem().AlignRight().Text(label).Bold();
                    r.RelativeItem().AlignLeft().Text(value).Bold();
                });
            }

            foreach (var f in data.FooterFields)
            {
                col.Item().Row(r =>
                {
                    r.RelativeItem().AlignRight().Text(f.Label).Bold();
                    r.RelativeItem().AlignLeft().Text(f.Value ?? "—").Bold();
                });
            }
        });
    }

    private static void BuildOfficialFooter(IContainer c, bool isA5, string rightText)
    {
        c.PaddingTop(4).BorderTop(0.8f).BorderColor("#d1d5db").Row(row =>
        {
            // RTL (ContentFromRightToLeft): عنوان راست‌ترین و «صفحه x از y» سمت چپ.
            row.RelativeItem().AlignRight().Text(rightText).FontSize(isA5 ? 7 : 8).FontColor("#9ca3af");
            row.RelativeItem().AlignLeft().Text(t =>
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
        => c.Background("#f3f4f6").Border(0.4f).BorderColor("#d1d5db").Padding(4)
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
        => c.Border(0.4f).BorderColor("#d1d5db").Padding(4)
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

    private static string SourceLabel(string? source) => Tarazin.Models.TreasurySourceLabels.For(source);
}
