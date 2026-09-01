using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Tarazin.Models;
using Tarazin.Services;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گارد چاپ سند: با فعال‌شدن ContentFromRightToLeft در کل سند، QuestPDF اولین
    /// آیتم هر Row را راست‌ترین می‌گذارد. پس در هدر باید **لوگو اول** (راست‌ترین)،
    /// سپس متن، و QR آخر (چپ‌ترین) ساخته شود. باگ قبلی (ترتیب LTR دستی) لوگو را
    /// چپ‌ترین می‌کرد. این گارد ترتیب صحیح را در هر سه سازندهٔ هدر قفل می‌کند.
    /// </summary>
    public class PrintRtlGuards
    {
        [Fact]
        public void Header_builders_emit_logo_before_text_rtl()
        {
            var source = ReadPdfReportServiceSource();
            Assert.NotNull(source);

            foreach (var method in new[] { "BuildDocumentCompanyHeader", "BuildOfficialHeader", "BuildTemplateCompanyHeader" })
            {
                var body = ExtractMethod(source!, method);
                Assert.True(body is not null, $"متد {method} پیدا نشد");

                // لوگو باید قبل از متن ساخته شود (اولین آیتم Row = راست‌ترین در RTL).
                var logoIdx = body!.IndexOf("Background(\"#0f766e\")", StringComparison.Ordinal);
                if (logoIdx < 0)
                    logoIdx = body.IndexOf("TryLoadImage", StringComparison.Ordinal);
                var textIdx = body.IndexOf("AlignRight().Text", StringComparison.Ordinal);

                Assert.True(logoIdx >= 0, $"{method}: بلوک لوگو پیدا نشد");
                Assert.True(textIdx >= 0, $"{method}: متن هدر پیدا نشد");
                Assert.True(logoIdx < textIdx,
                    $"{method}: لوگو باید قبل از متن ساخته شود (راست‌ترین در RTL با ContentFromRightToLeft) — لوگو در {logoIdx} و متن در {textIdx}");

                // QR باید بعد از متن باشد (چپ‌ترین) — اگر در متد هست.
                var qrIdx = body.IndexOf("Image(qr", StringComparison.Ordinal);
                if (qrIdx < 0)
                    qrIdx = body.IndexOf("Image(qrPng)", StringComparison.Ordinal);
                if (qrIdx >= 0)
                    Assert.True(qrIdx > textIdx,
                        $"{method}: QR باید بعد از متن ساخته شود (چپ‌ترین در RTL) — QR در {qrIdx} و متن در {textIdx}");
            }
        }

        [Fact]
        public void All_pages_use_content_from_right_to_left()
        {
            var source = ReadPdfReportServiceSource();
            Assert.NotNull(source);

            // هر ۵ متد Page باید ContentFromRightToLeft داشته باشند تا کل سند RTL باشد
            // (نه شبیه‌سازی دستی بخش‌به‌بخش که همیشه ناهماهنگ می‌ماند).
            var count = 0;
            var idx = 0;
            while ((idx = source!.IndexOf("page.ContentFromRightToLeft()", idx, StringComparison.Ordinal)) >= 0)
            {
                count++;
                idx += "page.ContentFromRightToLeft()".Length;
            }
            Assert.True(count >= 5, $"انتظار حداقل ۵ متد Page با ContentFromRightToLeft، ولی فقط {count} یافت شد");
        }

        /// <summary>
        /// گارد سیم‌کشی صفحه→هدر: هر متد Page نه‌تنها باید سازندهٔ هدر درست را صدا بزند
        /// (فاکتور/چک‌ها/جدول‌های عمومی → BuildOfficialHeader، سند → BuildDocumentCompanyHeader،
        /// قالب → BuildTemplateCompanyHeader) بلکه ContentFromRightToLeft باید **قبل از**
        /// page.Header() بیاید تا خود هدر هم RTL شود — نه فقط بدنه.
        /// </summary>
        [Fact]
        public void Page_methods_wire_rtl_header_builders()
        {
            var source = ReadPdfReportServiceSource();
            Assert.NotNull(source);

            // صفحه → سازندهٔ هدری که باید صدا بزند (همان ترتیب RTL: لوگو راست‌ترین).
            // BuildInvoicePdf اکنون به BuildInvoicePdfCore delegate می‌کند (گزینهٔ
            // «همهٔ ردیف‌ها در یک صفحه» با فشرده‌سازی خودکار) — پس RTL در Core است.
            var wiring = new Dictionary<string, string>
            {
                ["BuildInvoicePdfCore"] = "BuildOfficialHeader",
                ["BuildDocumentPdf"] = "BuildDocumentCompanyHeader",
                ["BuildChequeReportPdf"] = "BuildOfficialHeader",
                ["BuildTablePdf"] = "BuildOfficialHeader",
                ["BuildTemplatePdf"] = "BuildTemplateCompanyHeader",
            };

            foreach (var (method, headerBuilder) in wiring)
            {
                var body = ExtractMethod(source!, method);
                Assert.True(body is not null, $"متد {method} پیدا نشد");

                // ۱) RTL باید قبل از هدر اعمال شود تا هدر هم راست‌چین باشد.
                var rtlIdx = body!.IndexOf("ContentFromRightToLeft()", StringComparison.Ordinal);
                var headerIdx = body.IndexOf("page.Header()", StringComparison.Ordinal);
                Assert.True(rtlIdx >= 0, $"{method}: ContentFromRightToLeft() پیدا نشد");
                Assert.True(headerIdx >= 0, $"{method}: page.Header() پیدا نشد");
                Assert.True(rtlIdx < headerIdx,
                    $"{method}: ContentFromRightToLeft باید قبل از page.Header() باشد تا هدر هم RTL شود — RTL در {rtlIdx}، Header در {headerIdx}");

                // ۲) سازندهٔ هدر درست صدا زده شود (همان که گارد هدر آن را RTL می‌داند).
                Assert.True(body.Contains(headerBuilder, StringComparison.Ordinal),
                    $"{method}: باید {headerBuilder} را صدا بزند تا هدر RTL بماند");
            }
        }

        /// <summary>
        /// برون‌ریزی سه PDF (فاکتور طلا، گزارش چک‌ها، قالب چاپ) برای تأیید ساختاری هدر
        /// راست‌چین با pymupdf (لوگو راست‌ترین عنصر — x بزرگ نزدیک لبهٔ راست).
        /// </summary>
        /// <summary>
        /// گارد ضد-تکرار دانلود: دو کلیک متوالی روی «دانلود PDF» نام فایل را خراب می‌کرد
        /// (race دو دانلود موازی در WebView ⇒ فایل فقط بخشی از نام می‌شد). print-pdf.js باید
        /// یک صف سریالی (downloadQueue) + dedupe بر اساس نام داشته باشد تا هم‌زمان فقط یک
        /// دانلود اجرا/نام‌گذاری شود و همان نام تکراری نادیده گرفته شود.
        /// </summary>
        /// <summary>
        /// گارد ترتیب ستون‌های جدول RTL (ContentFromRightToLeft): با فعال‌شدن
        /// راست‌به‌چپ در کل سند، QuestPDF اولین ستون تعریف‌شده را راست‌ترین می‌گذارد.
        /// پس در هر سازندهٔ جدولِ سخت‌کدشده، ستونِ «کد/ردیف/شماره» باید اولین (راست‌ترین)
        /// و ستونِ «جمع/بستانکار/منبع» باید آخرین (چپ‌ترین) باشد. این گارد ترتیبِ
        /// هدرِ هر جدول را علیه برگشتی که ستون‌ها را به ترتیب LTR برمی‌گرداند قفل می‌کند.
        /// </summary>
        [Fact]
        public void Table_columns_keep_rtl_order_first_code_last_amount()
        {
            var source = ReadPdfReportServiceSource();
            Assert.NotNull(source);

            // سازندهٔ جدول → [اولینِ هدر (رشتهٔ آغازین)، آخرینِ هدر]
            var tables = new Dictionary<string, (string First, string Last)>
            {
                ["BuildInvoiceLines"] = ("ردیف", "جمع"),
                ["BuildDocumentTable"] = ("کد حساب", "بستانکار"),
                ["BuildDocumentAdvancedTable"] = ("کد", "بستانکار"),
                ["BuildChequeTable"] = ("شماره", "منبع"),
            };

            foreach (var (builder, expected) in tables)
            {
                var body = ExtractMethod(source!, builder);
                Assert.True(body is not null, $"سازندهٔ جدول {builder} پیدا نشد");

                // ۱) جدول باید داخل سندِ ContentFromRightToLeft باشد — هدرِ سلول‌ها از HeaderCell (RTL) ساخته شود.
                Assert.True(body!.Contains("HeaderCell", StringComparison.Ordinal),
                    $"{builder}: باید از HeaderCell برای هدر استفاده کند (RTL)");

                // ۲) ترتیب ستون‌ها: اولین هدر «کد/ردیف/شماره» و آخرین «جمع/بستانکار/منبع».
                var headers = ExtractHeaderLabels(body);
                Assert.True(headers.Count >= 2, $"{builder}: هدر جدول حداقل دو ستون باید داشته باشد");

                Assert.True(headers[0].StartsWith(expected.First, StringComparison.Ordinal),
                    $"{builder}: اولین ستون باید \"{expected.First}\" (راست‌ترین در RTL) باشد ولی \"{headers[0]}\" است.");
                Assert.True(headers[^1].Contains(expected.Last, StringComparison.Ordinal),
                    $"{builder}: آخرین ستون باید شامل \"{expected.Last}\" (چپ‌ترین در RTL) باشد ولی \"{headers[^1]}\" است.");
            }
        }

        /// <summary>
        /// استخراج برچسب‌های هدرِ سلول‌ها (به ترتیب تعریف) از بدنهٔ سازندهٔ جدول —
        /// با گرفتن متن‌های `.Text("...")` بعد از هر `HeaderCell`. چون کل سند RTL است،
        /// ترتیبِ تعریف‌شده همان ترتیبِ راست←چپِ نمایشی است.
        /// </summary>
        private static List<string> ExtractHeaderLabels(string tableBody)
        {
            var labels = new List<string>();
            // هم شکل قدیمی «Element(HeaderCell).Text("...")» و هم مقیاس‌پذیرِ جدید
            // «Element(c => HeaderCellScaled(c, s)).Text("...")» (فشرده‌سازی یک صفحه).
            var pattern = new System.Text.RegularExpressions.Regex(
                "HeaderCell\\w*(?:\\([^)]*\\))?\\)?\\.Text\\(\"([^\"]+)\"\\)");
            foreach (System.Text.RegularExpressions.Match m in pattern.Matches(tableBody))
                labels.Add(m.Groups[1].Value);
            return labels;
        }

        [Fact]
        public void PrintPdfJs_has_serialized_download_queue_and_dedupe()
        {
            var source = ReadPrintPdfJs();
            Assert.NotNull(source);
            Assert.True(source!.Contains("_downloadQueue", StringComparison.Ordinal),
                "print-pdf.js باید صف سریالی _downloadQueue برای دانلود داشته باشد");
            Assert.True(source.Contains("_lastDownloadName", StringComparison.Ordinal),
                "print-pdf.js باید _lastDownloadName برای dedupe داشته باشد");
            Assert.True(source.Contains("Promise.resolve()", StringComparison.Ordinal),
                "صف دانلود باید از Promise.resolve() شروع شود تا سریالی باشد");

            // ۱) زنجیرهٔ سریالی: هر دانلود به انتهای صف با then(run, run) الحاق می‌شود —
            //    نه Promise.all موازی (که race دو دانلود و خراب‌شدن نام فایل را برمی‌گرداند).
            const string Chain = "window.tarazin._downloadQueue.then(run, run)";
            var first = source.IndexOf(Chain, StringComparison.Ordinal);
            Assert.True(first >= 0,
                "صف باید با _downloadQueue.then(run, run) زنجیره شود تا دانلودها سریالی باشند (نه Promise.all موازی)");
            var second = source.IndexOf(Chain, first + Chain.Length, StringComparison.Ordinal);
            Assert.True(second < 0,
                "زنجیرهٔ _downloadQueue.then(run, run) باید دقیقاً یک بار باشد — دو بار یعنی موازی‌سازیِ race برگشته است");

            // ۲) ترتیب: ثبت نام (dedupe) قبل از زنجیره — تا همان لحظهٔ درخواستِ تکراری رد شود.
            var dedupeSet = source.IndexOf("_lastDownloadName = file", StringComparison.Ordinal);
            Assert.True(dedupeSet >= 0 && dedupeSet < first,
                "ترتیب باید باشد: _lastDownloadName = file (ثبت dedupe) قبل از _downloadQueue.then(run, run)");

            // ۳) await روی خودِ صف + ریست نام در finally بعد از آن — dedupe فقط همان کلیکِ
            //    تکراری را می‌گیرد و پس از پایان دانلود، نام برای درخواست بعدی آزاد می‌شود.
            var awaitIdx = source.IndexOf("return await window.tarazin._downloadQueue", StringComparison.Ordinal);
            Assert.True(awaitIdx >= 0,
                "دانلود باید روی خودِ صف await کند تا نتیجهٔ سریالی برگردد");
            var finallyIdx = source.IndexOf("finally", awaitIdx, StringComparison.Ordinal);
            Assert.True(finallyIdx >= 0,
                "بعد از await صف باید بلوک finally برای ریست dedupe وجود داشته باشد");
            var reset = source.IndexOf("_lastDownloadName = null", finallyIdx, StringComparison.Ordinal);
            Assert.True(reset >= 0,
                "finally باید _lastDownloadName را null کند تا dedupe فقط همان کلیک تکراری را بگیرد");
        }

        /// <summary>
        /// گارد سورسِ گام‌های pymupdf: هر سه حالت (all/generic/a5l) باید در
        /// <c>tools/check-rtl-headers.sh</c> تعریف و گام‌های نام‌دار «۴ب/۴ج» در
        /// <c>tools/run-checks.sh</c> صدا زده شوند — تا حذفِ اتفاقی گارد A5L
        /// (یا حالت generic) دوباره تکرار نشود و CI همان step جدا را نگه دارد.
        /// </summary>
        [Fact]
        public void RunChecks_invokes_all_pymupdf_guard_modes()
        {
            var runChecks = ReadRepoFile("tools", "run-checks.sh");
            Assert.NotNull(runChecks);

            // گام ۴ب — گارد عمومی هدر راست‌چین
            Assert.Contains("check-rtl-headers.sh generic", runChecks!, StringComparison.Ordinal);
            // گام ۴ج — گارد A5L قالب چاپ (step جدا در run-checks.sh و CI)
            Assert.Contains("check-rtl-headers.sh a5l", runChecks!, StringComparison.Ordinal);
            // گام ۴د — گارد A5L جدول عمومی (BuildTablePdf)
            Assert.Contains("check-rtl-headers.sh table", runChecks, StringComparison.Ordinal);
            // گام ۴هـ — گارد A5L بدون هدر (QR مستقل جایگزین لوگو)
            Assert.Contains("check-rtl-headers.sh noheader", runChecks, StringComparison.Ordinal);
            // گام ۴و — گارد چندصفحه‌گی جدول عمومی (BuildTablePdf با ۶۰+ ردیف، هدر در هر صفحه)
            Assert.Contains("check-rtl-headers.sh table-many", runChecks, StringComparison.Ordinal);
            // گام ۴ز — گارد A5L فاکتور طلا (BuildInvoicePdf با ردیف‌های زیاد: MediaBox و بدون بیرون‌زدگی)
            // دو لایه: xUnit ساختاری نام‌دار + pymupdf (هدر در هر صفحه) — حذفِ هر کدام Fail می‌شود.
            Assert.Contains("check-rtl-headers.sh invoice-a5l-many", runChecks, StringComparison.Ordinal);
            Assert.Contains("FullyQualifiedName~BuildInvoicePdf_a5l_many_rows_multipage_no_overflow", runChecks, StringComparison.Ordinal);
            Assert.Contains("۴ز) گارد BuildInvoicePdf A5L چندصفحه", runChecks, StringComparison.Ordinal);
            // گام ۴ح — گارد بدون بیرون‌زدگی سند ۳۲ ردیفه (xUnit نام‌دار، A5 و A5L)
            Assert.Contains("FullyQualifiedName~BuildDocumentPdf_a5_32plus_lines_multipage_no_overflow", runChecks, StringComparison.Ordinal);
            Assert.Contains("۴ح) گارد BuildDocumentPdf ۳۲ ردیفه", runChecks, StringComparison.Ordinal);
            // گام ۴ط — گارد «هدر فقط روی صفحاتِ حاوی جدول» (pymupdf — A5 پرتوره با صفحهٔ جمع‌بندی)
            Assert.Contains("check-rtl-headers.sh table-summary-pages", runChecks, StringComparison.Ordinal);
            Assert.Contains("۴ط) گارد هدر فقط روی صفحاتِ دارای جدول", runChecks, StringComparison.Ordinal);
            // گام ۴ی — چیپ تعداد صفحهٔ فاکتور/چک: helperها باید با همان بایت‌های دانلود هم‌راستا باشند
            Assert.Contains("FullyQualifiedName~Invoice_and_cheque_page_count_helpers_match_the_direct_builders", runChecks, StringComparison.Ordinal);
            Assert.Contains("۴ی) چیپ تعداد صفحه فاکتور/چک", runChecks, StringComparison.Ordinal);
            // گام ۳ب — گارد فونت Vazirmatn (VazirmatnFontRegistrationTests) — نباید روثبت‌نشده حذف شود
            Assert.Contains("FullyQualifiedName~VazirmatnFontRegistrationTests", runChecks, StringComparison.Ordinal);
            Assert.Contains("۳ب) گارد فونت Vazirmatn", runChecks, StringComparison.Ordinal);

            var headers = ReadRepoFile("tools", "check-rtl-headers.sh");
            Assert.NotNull(headers);

            // هر هشت حالت باید تعریف‌شده باشند: all (پیش‌فرض، همهٔ گاردها) و گام‌های نام‌دار
            Assert.Contains("[all|generic|a5l|table|noheader|table-many|invoice-a5l-many|table-summary-pages]", headers!, StringComparison.Ordinal);
            Assert.Contains("generic) run_generic", headers, StringComparison.Ordinal);
            Assert.Contains("a5l)     run_a5l", headers, StringComparison.Ordinal);
            Assert.Contains("table)   run_table_a5l", headers, StringComparison.Ordinal);
            Assert.Contains("noheader) run_a5l_noheader", headers, StringComparison.Ordinal);
            Assert.Contains("table-many) run_table_many", headers, StringComparison.Ordinal);
            Assert.Contains("invoice-a5l-many) run_invoice_a5l_many", headers, StringComparison.Ordinal);
            Assert.Contains("table-summary-pages) run_table_summary_pages", headers, StringComparison.Ordinal);
            // حالت پیش‌فرض «all» (case *) هر شش گارد را اجرا می‌کند
            Assert.Contains("*)", headers, StringComparison.Ordinal);
            Assert.Contains("run_generic || OK=1", headers, StringComparison.Ordinal);
            Assert.Contains("run_a5l || OK=1", headers, StringComparison.Ordinal);
            Assert.Contains("run_table_a5l || OK=1", headers, StringComparison.Ordinal);
            Assert.Contains("run_a5l_noheader || OK=1", headers, StringComparison.Ordinal);
            Assert.Contains("run_table_many || OK=1", headers, StringComparison.Ordinal);
            Assert.Contains("run_invoice_a5l_many || OK=1", headers, StringComparison.Ordinal);
            Assert.Contains("run_table_summary_pages || OK=1", headers, StringComparison.Ordinal);
        }

        private static string? ReadRepoFile(params string[] segments)
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            for (var d = dir; d is not null; d = d.Parent)
            {
                if (Directory.Exists(Path.Combine(d.FullName, "Tarazin.Ui", "wwwroot")))
                {
                    var path = Path.Combine(new[] { d.FullName }.Concat(segments).ToArray());
                    return File.Exists(path) ? File.ReadAllText(path) : null;
                }
            }
            return null;
        }

        [Fact]
        public void Dump_rtl_header_pdfs_for_pymupdf()
        {
            var svc = new PdfReportService();
            var dir = Path.Combine(Path.GetTempPath(), "tarazin-pdf", "rtl-headers");
            Directory.CreateDirectory(dir);

            // فاکتور طلا (BuildOfficialHeader)
            File.WriteAllBytes(Path.Combine(dir, "invoice.pdf"),
                svc.BuildInvoicePdf(SampleInvoice(4), "A4"));

            // فاکتور طلا در A5 افقی با ۲۵ ردیف (BuildInvoicePdf با override «A5L»):
            // باید (۱) MediaBox A5 landscape ≈ ۵۹۵×۴۲۰ باشد، (۲) چندصفحه شود و هدرِ
            // جدول در هر صفحه تکرار شود، (۳) هیچ محتوایی از لبه بیرون نزند. این فایل
            // ورودیِ step واقعی pymupdf «invoice-a5l-many» در tools/check-rtl-headers.sh است.
            File.WriteAllBytes(Path.Combine(dir, "invoice-a5l-many.pdf"),
                svc.BuildInvoicePdf(SampleInvoice(25), "A5L"));

            // گزارش چک‌ها (BuildOfficialHeader)
            File.WriteAllBytes(Path.Combine(dir, "cheque.pdf"),
                svc.BuildChequeReportPdf(SampleCheques(), "A4"));

            // قالب چاپ (BuildTemplateCompanyHeader) — با هدر شرکت روشن
            var tpl = PrintTemplates.Defaults.Get("treasury.cheques");
            tpl.ShowCompanyHeader = true;
            var data = BuildSample(tpl);
            File.WriteAllBytes(Path.Combine(dir, "template.pdf"),
                svc.BuildTemplatePdf(tpl, data));

            // قالب چاپ در A5 افقی (BuildTemplatePdf با override "A5L"): باید landscape
            // (MediaBox ≈ 595×420) و هدرش RTL بماند — این فایل ورودیِ step واقعی pymupdf
            // در tools/check-rtl-headers.sh است که MediaBox و راست‌چینی هدر را هر دو می‌سنجد.
            File.WriteAllBytes(Path.Combine(dir, "template-a5l.pdf"),
                svc.BuildTemplatePdf(tpl, data, "A5L"));

            // قالب چاپ در A5 افقی ولی **هدر شرکت خاموش** و QR روشن: هدر رسمی نیست پس
            // لوگوی سبز هم نیست — QR مستقل باید در گوشهٔ بالای راست جایگزین لوگو شود.
            // ورودیِ step «noheader» در tools/check-rtl-headers.sh که رسماً skip نمی‌شود
            // بلکه تشخیص می‌دهد QR مستقل جای لوگو نشسته (بدون لوگو + تصویر QR بالا-راست).
            var tplNoHeader = PrintTemplates.Defaults.Get("treasury.cheques");
            tplNoHeader.ShowCompanyHeader = false;
            tplNoHeader.QrEnabled = true;
            var dataNh = BuildSample(tplNoHeader);
            dataNh.QrEnabled = true;
            dataNh.QrPayload = $"tarazin:tpl:{tplNoHeader.Id}";
            File.WriteAllBytes(Path.Combine(dir, "template-a5l-noheader.pdf"),
                svc.BuildTemplatePdf(tplNoHeader, dataNh, "A5L"));

            // گزارش جدولی عمومی (BuildTablePdf → BuildOfficialHeader) — با دادهٔ واقعی
            var tableColumns = new List<TableReportColumn>
            {
                new() { Header = "شماره چک" },
                new() { Header = "بانک" },
                new() { Header = "جهت" },
                new() { Header = "سررسید" },
                new() { Header = "مبلغ", AlignRight = true },
            };
            var tableRows = new List<IReadOnlyList<string>>
            {
                new[] { "CHQ-50001", "بانک صادرات ایران", "دریافتی", "1405/06/02", "500٬000٬000" },
                new[] { "CHQ-10001", "بانک ملی ایران", "دریافتی", "1405/06/24", "75٬000٬000" },
                new[] { "CHQ-20001", "بانک ملت", "پرداختی", "1405/07/01", "20٬000٬000" },
            };
            File.WriteAllBytes(Path.Combine(dir, "table.pdf"),
                svc.BuildTablePdf(
                    "گزارش چک‌ها",
                    "چک‌های در جریان و سررسیدشده",
                    "از 1405/05/07 تا 1405/06/07",
                    tableColumns,
                    tableRows,
                    summaryLines: new[] { "جمع مبلغ: ۵۹۵٬۰۰۰٬۰۰۰" },
                    companyName: "ترازین — سامانه یکپارچه",
                    companyAddress: "تهران، خیابان آزادی",
                    qrPayload: "https://tarazin.app/trace/table"));

            // جدول عمومی در A5 افقی (BuildTablePdf با override «A5L»): مثل قالب، باید
            // landscape (MediaBox ≈ 595×420) و هدرش RTL بماند — ورودیِ step واقعی pymupdf
            // «table» در tools/check-rtl-headers.sh که MediaBox و راست‌چینی هدر را می‌سنجد.
            File.WriteAllBytes(Path.Combine(dir, "table-a5l.pdf"),
                svc.BuildTablePdf(
                    "گزارش چک‌ها",
                    "چک‌های در جریان و سررسیدشده",
                    "از 1405/05/07 تا 1405/06/07",
                    tableColumns,
                    tableRows,
                    summaryLines: new[] { "جمع مبلغ: ۵۹۵٬۰۰۰٬۰۰۰" },
                    paperSize: "A5L",
                    companyName: "ترازین — سامانه یکپارچه",
                    companyAddress: "تهران، خیابان آزادی",
                    qrPayload: "https://tarazin.app/trace/table"));

            // جدول عمومی در A5 **پرتره** با جمع‌بندی که به‌تنهایی صفحهٔ آخر را می‌گیرد:
            // ۲۰ ردیف طوری‌ست که صفحهٔ ۱ = جدول (هدر + ردیف‌ها) و صفحهٔ ۲ = فقط جمع‌بندی
            // (بدون هدر جدول و بدون ردیف). این فایل ورودیِ step «table-summary-pages» در
            // tools/check-rtl-headers.sh است که «هدر فقط روی صفحاتِ حاوی جدول» را می‌سنجد
            // — صفحهٔ جمع‌بندی بدون هدر باید رسماً معتبر باشد نه Fail.
            var summaryRows = new List<IReadOnlyList<string>>();
            for (var i = 1; i <= 20; i++)
                summaryRows.Add(new[] { $"CHQ-{i:00000}", "بانک صادرات ایران", "دریافتی", "1405/06/02", (i * 1_000_000L).ToString("N0") });
            File.WriteAllBytes(Path.Combine(dir, "table-a5-summary.pdf"),
                svc.BuildTablePdf(
                    "گزارش چک‌ها",
                    "چک‌های در جریان و سررسیدشده",
                    "از 1405/05/07 تا 1405/06/07",
                    tableColumns,
                    summaryRows,
                    summaryLines: new[] { "جمع مبلغ: ۲۱۰٬۰۰۰٬۰۰۰", "خط دوم جمع‌بندی برای اطمینان از جا نماندن" },
                    paperSize: "A5",
                    companyName: "ترازین — سامانه یکپارچه",
                    companyAddress: "تهران، خیابان آزادی",
                    qrPayload: "https://tarazin.app/trace/table-summary"));

            // جدول عمومی بلند (۶۵ ردیف) در A5 افقی: باید چندصفحه شود و **هدرِ جدول در هر
            // صفحه تکرار شود** — ورودیِ step «table-many» در tools/check-rtl-headers.sh که
            // صفحه‌ها را می‌شمارد و متن هر صفحه را برای برچسب هدر «شماره چک» می‌سنجد.
            var manyRows = new List<IReadOnlyList<string>>();
            for (var i = 1; i <= 65; i++)
                manyRows.Add(new[] { $"CHQ-{i:00000}", "بانک صادرات ایران", "دریافتی", "1405/06/02", (i * 1_000_000L).ToString("N0") });
            File.WriteAllBytes(Path.Combine(dir, "table-a5l-many.pdf"),
                svc.BuildTablePdf(
                    "گزارش چک‌ها",
                    "چک‌های در جریان و سررسیدشده",
                    "از 1405/05/07 تا 1405/06/07",
                    tableColumns,
                    manyRows,
                    summaryLines: new[] { "جمع مبلغ: ۲٬۱۴۵٬۰۰۰٬۰۰۰" },
                    paperSize: "A5L",
                    companyName: "ترازین — سامانه یکپارچه",
                    companyAddress: "تهران، خیابان آزادی",
                    qrPayload: "https://tarazin.app/trace/table-many"));
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

        private static PrintDataModel BuildSample(PrintTemplateDef tpl)
        {
            var data = new PrintDataModel
            {
                Title = tpl.ReportTitle,
                Subtitle = tpl.ReportSubtitle,
                RangeText = "از 1405/05/07 تا 1405/06/07",
                CompanyName = "ترازین — سامانه یکپارچه مدیریت کسب‌وکار",
                CompanyAddress = "تهران، خیابان آزادی",
                MetaFields = tpl.MetaFields.Select(m => new PrintMetaField
                {
                    Label = m.Label,
                    Value = m.Label switch
                    {
                        "بازه" => "1405/05/07 تا 1405/06/07",
                        "تعداد اقلام" => "5",
                        _ => "—"
                    }
                }).ToList(),
                FooterFields = new List<PrintMetaField>()
            };

            for (var i = 1; i <= 4; i++)
            {
                var row = new PrintRow();
                foreach (var col in tpl.Columns)
                    row[col.Key] = col.Key switch
                    {
                        "ChequeNumber" => $"CHQ-{i:00000}",
                        "BankName" => "بانک صادرات ایران",
                        "Direction" => "دریافتی",
                        "StatusTitle" => "در انتظار",
                        "DueDate" => "1405/06/02",
                        "AlertTitle" => "سررسیدشده",
                        "Amount" => 500000000m + i,
                        "SourceReference" => "دستی",
                        _ => "—"
                    };
                data.Rows.Add(row);
            }
            return data;
        }

        private static string? ReadPrintPdfJs()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            var root = (DirectoryInfo?)null;
            for (var d = dir; d is not null; d = d.Parent)
            {
                if (Directory.Exists(Path.Combine(d.FullName, "Tarazin.Ui", "wwwroot")))
                {
                    root = d;
                    break;
                }
            }
            if (root is null) return null;
            var path = Path.Combine(root.FullName, "Tarazin.Ui", "wwwroot", "js", "print-pdf.js");
            return File.Exists(path) ? File.ReadAllText(path) : null;
        }

        private static string? ReadPdfReportServiceSource()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            var root = (DirectoryInfo?)null;
            for (var d = dir; d is not null; d = d.Parent)
            {
                if (Directory.Exists(Path.Combine(d.FullName, "Tarazin.Ui", "Services")))
                {
                    root = d;
                    break;
                }
            }
            if (root is null) return null;
            var path = Path.Combine(root.FullName, "Tarazin.Ui", "Services", "PdfReportService.cs");
            return File.Exists(path) ? File.ReadAllText(path) : null;
        }

        private static string? ExtractMethod(string source, string methodName)
        {
            // فقط تعریف متد (نه فراخوانی): «(public|private|internal) ... MethodName(»
            // در ابتدای خط — فراخوانی‌هایی مثل «h => BuildDocumentCompanyHeader(...)»
            // داخل بدنهٔ متدهای دیگر نباید پیدا شوند.
            var pattern = new System.Text.RegularExpressions.Regex(
                $@"^\s*(?:private|public|internal|protected)\s+(?:static\s+)?[\w<>\[\].,?\s]+\s{methodName}\s*\(",
                System.Text.RegularExpressions.RegexOptions.Multiline);
            var m = pattern.Match(source);
            if (!m.Success) return null;
            var brace = source.IndexOf('{', m.Index);
            if (brace < 0) return null;
            var depth = 0;
            for (var i = brace; i < source.Length; i++)
            {
                if (source[i] == '{') depth++;
                else if (source[i] == '}') depth--;
                if (depth == 0) return source.Substring(m.Index, i - m.Index + 1);
            }
            return source.Substring(m.Index);
        }
    }
}
