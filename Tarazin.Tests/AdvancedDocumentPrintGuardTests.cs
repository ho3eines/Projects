using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Tarazin.Models;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گارد ترتیبی چاپ پیشرفتهٔ سند با دادهٔ زنده: سند واقعی دیتابیس (32 ردیف،
    /// DocumentId=1547) را از طریق همان اسکریپت‌های UI (DocumentById + DocumentLines +
    /// DocumentPrintRollup) بارگذاری می‌کند و قفل می‌کند که در مدل چاپ پیشرفته
    /// (Kol←Moein←تفصیل) هر تفصیل دقیقاً زیر معین خودش و هر معین زیر کل خودش بیاید و
    /// جمع هر سطح با جمع ردیف‌های زیرمجموعه‌اش برابر باشد.
    /// دو گارد: (۱) چیدمان دستی با همان قواعد GROUP BY اسکریپت، (۲) صدازدنِ خودِ
    /// <c>AdvancedDocRowsBuilder.Build</c> — همان متدی که DocumentPrintDialog و
    /// PdfReportService.BuildDocumentPdf هر دو استفاده می‌کنند (منبع واحد حقیقت).
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود.
    /// </summary>
    public class AdvancedDocumentPrintGuardTests
    {
        private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/accounting";
        private const int TargetDoc = 1547; // سند واقعی 32 ردیفی در دیتابیس توسعه
        private const int TargetCompany = 3;
        private const int TargetFy = 4;

        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

        /// <summary>بارگذاری سند 1547 با همان اسکریپت‌های UI (سرصفحه + ردیف‌ها + رول‌آپ).</summary>
        private static async Task<LoadedDoc> LoadDoc1547Async(Microsoft.Data.SqlClient.SqlConnection cn)
        {
            var header = await cn.QueryFirstOrDefaultAsync<DocHeader>(
                Script("DocumentById.sql"),
                new { DocumentId = TargetDoc, CompanyId = TargetCompany, FiscalYearId = TargetFy });
            if (header is null)
                throw new SkipException($"سند {TargetDoc} در دیتابیس نبود");

            var lines = (await cn.QueryAsync<DocumentLineRow>(
                Script("DocumentLines.sql"),
                new { DocumentId = TargetDoc, CompanyId = TargetCompany, FiscalYearId = TargetFy })).ToList();

            var rollup = (await cn.QueryAsync<RollupRow>(
                Script("DocumentPrintRollup.sql"),
                new { DocumentId = TargetDoc, CompanyId = TargetCompany })).ToList();

            Assert.Equal(32, lines.Count); // باید همان سند 32 ردیفی باشد

            return new LoadedDoc(header, lines, rollup);
        }

        /// <summary>
        /// گارد ترتیبی چاپ پیشرفته: با همان منطق BuildAdvancedRows دیالوگ (کل ← معین ← تفصیل)
        /// ردیف‌ها را می‌چیند و قفل می‌کند که (۱) هر تفصیل دقیقاً زیر معینِ خودش و هر معین زیر
        /// کلِ خودش بیاید (بدون ردیف خارجی بینشان)، (۲) جمع هر سطح با جمع ردیف‌های زیرمجموعه‌اش
        /// برابر باشد (معین = جمع ردیف‌هایش، کل = جمع معین‌هایش = جمع همهٔ ردیف‌هایش).
        /// </summary>
        [SkippableFact]
        public async Task Advanced_ordering_and_level_sums_guard()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var loaded = await LoadDoc1547Async(cn);
            var kols = loaded.Kols;
            var moeins = loaded.Moeins;
            var lines = loaded.Lines;

            // ── کمکی: کد کل (۲ رقم اول) و کد معین (۵ رقم اول) — دقیقاً مثل GROUP BY اسکریپت ──
            static string KolCode(string accountCode)
                => accountCode.Substring(0, Math.Min(2, accountCode.Length));
            static string MoeinCode(string accountCode)
                => accountCode.Substring(0, Math.Min(5, accountCode.Length));

            // هر ردیف باید کد معین/کل قابل استخراج داشته باشد
            foreach (var l in lines)
            {
                Assert.True(l.AccountCode.Length >= 2, $"کد حساب خیلی کوتاه: «{l.AccountCode}»");
                Assert.Contains(kols, k => k.Code == KolCode(l.AccountCode));
                Assert.Contains(moeins, m => m.Code == MoeinCode(l.AccountCode));
            }

            // هر معین باید زیر دقیقاً یک کل باشد و هر کل حداقل یک معین داشته باشد
            foreach (var m in moeins)
            {
                Assert.True(m.Code.Length >= 2, $"کد معین خیلی کوتاه: «{m.Code}»");
                var owner = kols.Where(k => k.Code.Length >= 2 && m.Code.StartsWith(k.Code, StringComparison.Ordinal)).ToList();
                Assert.True(owner.Count == 1,
                    $"معین {m.Code} باید زیر دقیقاً یک کل باشد؛ یافت: {owner.Count}");
                Assert.Equal(KolCode(m.Code), owner[0].Code);
            }
            foreach (var k in kols)
                Assert.True(moeins.Any(m => m.Code.StartsWith(k.Code, StringComparison.Ordinal)),
                    $"کل {k.Code} هیچ معینی ندارد");

            // ── ساخت ترتیب دقیقاً مثل BuildAdvancedRows دیالوگ: کل → [معین → ردیف‌هایش] ──
            // ردیف چاپی: Level 0 = کل، 1 = معین، 2 = تفصیل
            var rows = new List<(int Level, string Code, decimal Debit, decimal Credit, int LineCount)>();
            var kolsSorted = kols.OrderBy(k => k.Code, StringComparer.Ordinal).ToList();
            foreach (var kol in kolsSorted)
            {
                // بلاک این کل را جدا می‌سازیم و به‌ترتیب به انتهای لیست اضافه می‌کنیم
                // (نه Insert(0, …) که ترتیب کل‌ها را در سندهای چندکل برعکس می‌کند).
                var block = new List<(int Level, string Code, decimal Debit, decimal Credit, int LineCount)>();

                var moeinsOfKol = moeins
                    .Where(m => m.Code.Length >= 2 && m.Code.StartsWith(kol.Code, StringComparison.Ordinal))
                    .OrderBy(m => m.Code, StringComparer.Ordinal).ToList();

                decimal kolDebit = 0, kolCredit = 0;
                int kolCount = 0;

                foreach (var moein in moeinsOfKol)
                {
                    var moeinLines = lines
                        .Where(l => l.AccountCode.StartsWith(moein.Code, StringComparison.Ordinal))
                        .OrderBy(l => l.AccountCode, StringComparer.Ordinal).ToList();
                    var mDebit = moeinLines.Sum(l => l.Debit);
                    var mCredit = moeinLines.Sum(l => l.Credit);
                    kolDebit += mDebit; kolCredit += mCredit; kolCount += moeinLines.Count;

                    block.Add((1, moein.Code, mDebit, mCredit, moeinLines.Count));
                    foreach (var l in moeinLines)
                        block.Add((2, l.AccountCode, l.Debit, l.Credit, 0));
                }

                block.Insert(0, (0, kol.Code, kolDebit, kolCredit, kolCount));
                rows.AddRange(block);
            }

            // ── (۱) ترتیب: هر تفصیل زیر معین خودش، هر معین زیر کل خودش، بدون ردیف خارجی ──
            // هر کل یک ردیف + هر معین یک ردیف + هر تفصیل یک ردیف (بدون ردیف اضافه/کم)
            var totalRows = kols.Count + moeins.Count + lines.Count;
            Assert.Equal(totalRows, rows.Count);

            int pos = 0;
            for (int ki = 0; ki < kolsSorted.Count; ki++)
            {
                var kol = kolsSorted[ki];
                // ردیف اولِ این بلاک باید خودِ کل باشد
                Assert.Equal(0, rows[pos].Level);
                Assert.Equal(kol.Code, rows[pos].Code);
                pos++;

                var moeinsOfKol = moeins
                    .Where(m => m.Code.Length >= 2 && m.Code.StartsWith(kol.Code, StringComparison.Ordinal))
                    .OrderBy(m => m.Code, StringComparer.Ordinal).ToList();
                foreach (var moein in moeinsOfKol)
                {
                    // ردیف معین، بلافاصله بعد از کل (یا آخرین تفصیل معین قبلی)
                    Assert.True(pos < rows.Count, $"معین {moein.Code} بعد از کل {kol.Code} پیدا نشد");
                    Assert.Equal(1, rows[pos].Level);
                    Assert.Equal(moein.Code, rows[pos].Code);
                    pos++;

                    // هر تفصیلِ بعدی تا وقتی که به ردیف معین/کل بعدی نرسیده، باید زیر همین معین باشد
                    while (pos < rows.Count && rows[pos].Level == 2)
                    {
                        Assert.True(rows[pos].Code.StartsWith(moein.Code, StringComparison.Ordinal),
                            $"تفصیل {rows[pos].Code} باید زیر معین {moein.Code} بیاید (ردیف خارجی بینشان است).");
                        pos++;
                    }
                }
                // بعد از بلوک این کل، یا کل بعدی است یا پایان
                Assert.True(pos == rows.Count || rows[pos].Level == 0,
                    $"بعد از کل {kol.Code} نباید ردیف سرگردانی باشد.");
            }
            Assert.Equal(rows.Count, pos); // همهٔ ردیف‌ها مصرف شدند

            // ── (۲) جمع هر سطح با جمع ردیف‌های زیرمجموعه‌اش برابر است ──
            // معین: جمع ردیف‌هایش == مقدار رول‌آپ
            foreach (var moein in moeins)
            {
                var moeinRows = rows.Where(r => r.Level == 2 && r.Code.StartsWith(moein.Code, StringComparison.Ordinal));
                var sumDeb = moeinRows.Sum(r => r.Debit);
                var sumCred = moeinRows.Sum(r => r.Credit);
                Assert.Equal(moein.Debit, sumDeb);
                Assert.Equal(moein.Credit, sumCred);
                Assert.Equal(moein.LineCount, moeinRows.Count());
            }
            // کل: جمع معین‌هایش (فقط ردیف‌های Level 1 — نه تفصیل‌های زیرشان، وگرنه دوبار شمرده می‌شوند)
            // == مقدار رول‌آپ == جمع همهٔ ردیف‌های تفصیل زیرش
            foreach (var kol in kols)
            {
                var kolMoeins = rows.Where(r => r.Level == 1 && r.Code.StartsWith(kol.Code, StringComparison.Ordinal));
                var kolDetails = rows.Where(r => r.Level == 2 && r.Code.StartsWith(kol.Code, StringComparison.Ordinal));
                Assert.Equal(kol.Debit, kolMoeins.Sum(r => r.Debit));
                Assert.Equal(kol.Credit, kolMoeins.Sum(r => r.Credit));
                Assert.Equal(kol.LineCount, kolDetails.Count());
                // جمع ردیف‌های تفصیل زیر کل هم باید همان مقدار باشد
                Assert.Equal(kol.Debit, kolDetails.Sum(r => r.Debit));
                Assert.Equal(kol.Credit, kolDetails.Sum(r => r.Credit));
            }
            // سراسری: بدهکار == بستانکار و جمع کل‌ها == جمع ردیف‌ها
            var totalDeb = lines.Sum(l => l.Debit);
            var totalCred = lines.Sum(l => l.Credit);
            Assert.Equal(totalDeb, totalCred); // سند متوازن
            Assert.Equal(totalDeb, kols.Sum(k => k.Debit));
            Assert.Equal(totalCred, kols.Sum(k => k.Credit));
        }

        /// <summary>
        /// گارد ترتیبی «خود متد تولید ردیف»: برخلاف گارد بالا (که منطق را دستی می‌چیند)،
        /// اینجا AdvancedDocRowsBuilder.Build — همان متدی که DocumentPrintDialog و
        /// PdfReportService.BuildDocumentPdf هر دو از آن استفاده می‌کنند — با دادهٔ زندهٔ
        /// سند ۳۲ ردیفی صدا زده می‌شود و قفل می‌کند که هر تفصیل دقیقاً زیر معین خودش، هر
        /// معین زیر کل خودش، بدون ردیف خارجی، و جمع هر سطح با جمع ردیف‌های زیرمجموعه‌اش
        /// برابر باشد. اگر کسی ترتیب/جمع‌بندی Builder را خراب کند، هم دیالوگ و هم PDF و
        /// هم این گارد یک‌جا می‌شکنند (منبع واحد حقیقت).
        /// </summary>
        [SkippableFact]
        public async Task AdvancedDocRowsBuilder_live_hierarchy_and_level_sums_guard()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var loaded = await LoadDoc1547Async(cn);
            var model = loaded.BuildModel();

            // ── خود متد واقعی تولید ردیف (دیالوگ/PDF) با دادهٔ زنده ──
            var rows = AdvancedDocRowsBuilder.Build(model.KolRows, model.MoeinRows, model.Lines);
            var kols = model.KolRows;
            var moeins = model.MoeinRows;
            var lines = model.Lines;

            // هر ردیف باید کد معین/کل قابل استخراج داشته باشد
            static string KolCode(string accountCode)
                => accountCode.Substring(0, Math.Min(2, accountCode.Length));
            static string MoeinCode(string accountCode)
                => accountCode.Substring(0, Math.Min(5, accountCode.Length));

            foreach (var l in lines)
            {
                Assert.True(l.AccountCode.Length >= 2, $"کد حساب خیلی کوتاه: «{l.AccountCode}»");
                Assert.Contains(kols, k => k.Code == KolCode(l.AccountCode));
                Assert.Contains(moeins, m => m.Code == MoeinCode(l.AccountCode));
            }

            // ── (۱) ساختار/تعداد: دقیقاً کل + معین + تفصیل ──
            Assert.Equal(kols.Count + moeins.Count + lines.Count, rows.Count);
            Assert.True(rows.Count > 0, "Builder هیچ ردیفی نساخت");

            // ── (۲) ترتیب: ردیف‌های کل سپس بلاک معین/تفصیل زیر همان کل ──
            // مسیر حرکت: هر Level 0 شروع یک بلاک است؛ داخل بلاک، Level 1 معین و Level 2
            // تفصیلِ زیر همان معین تا رسیدن به Level 1/0 بعدی (بدون ردیف خارجی).
            var kolsSorted = kols.OrderBy(k => k.Code, StringComparer.Ordinal).ToList();
            int pos = 0;
            foreach (var kol in kolsSorted)
            {
                // ردیف اولِ این بلاک باید خودِ کل باشد
                Assert.True(pos < rows.Count, $"کل {kol.Code} در ردیف‌های Builder پیدا نشد");
                Assert.Equal(0, rows[pos].Level);
                Assert.Equal(kol.Code, rows[pos].Code);
                pos++;

                var moeinsOfKol = moeins
                    .Where(m => m.Code.Length >= 2 && m.Code.StartsWith(kol.Code, StringComparison.Ordinal))
                    .OrderBy(m => m.Code, StringComparer.Ordinal).ToList();
                foreach (var moein in moeinsOfKol)
                {
                    Assert.True(pos < rows.Count, $"معین {moein.Code} بعد از کل {kol.Code} یافت نشد");
                    Assert.Equal(1, rows[pos].Level);
                    Assert.Equal(moein.Code, rows[pos].Code);
                    pos++;

                    while (pos < rows.Count && rows[pos].Level == 2)
                    {
                        Assert.True(rows[pos].Code.StartsWith(moein.Code, StringComparison.Ordinal),
                            $"تفصیل {rows[pos].Code} باید زیر معین {moein.Code} بیاید (ردیف خارجی بینشان است).");
                        pos++;
                    }
                }
                Assert.True(pos == rows.Count || rows[pos].Level == 0,
                    $"بعد از کل {kol.Code} نباید ردیف سرگردانی باشد.");
            }
            Assert.Equal(rows.Count, pos); // همهٔ ردیف‌ها مصرف شدند

            // ── (۳) جمع هر سطح با جمع ردیف‌های زیرمجموعه‌اش برابر است ──
            // معین: مقدار رول‌آپ == جمع تفصیل‌های Build شده == مقدار خود Builder
            foreach (var moein in moeins)
            {
                var moeinRows = rows.Where(r => r.Level == 2 && r.Code.StartsWith(moein.Code, StringComparison.Ordinal));
                Assert.Equal(moein.Debit, moeinRows.Sum(r => r.Debit));
                Assert.Equal(moein.Credit, moeinRows.Sum(r => r.Credit));
                Assert.Equal(moein.LineCount, moeinRows.Count());
            }
            // کل: جمع معین‌هایش == جمع همهٔ ردیف‌هایش == مقدار خود Builder
            foreach (var kol in kols)
            {
                var kolMoeins = rows.Where(r => r.Level == 1 && r.Code.StartsWith(kol.Code, StringComparison.Ordinal));
                var kolDetails = rows.Where(r => r.Level == 2 && r.Code.StartsWith(kol.Code, StringComparison.Ordinal));
                Assert.Equal(kol.Debit, kolMoeins.Sum(r => r.Debit));
                Assert.Equal(kol.Credit, kolMoeins.Sum(r => r.Credit));
                Assert.Equal(kol.LineCount, kolDetails.Count());
                Assert.Equal(kol.Debit, kolDetails.Sum(r => r.Debit));
                Assert.Equal(kol.Credit, kolDetails.Sum(r => r.Credit));
            }
            // سراسری: سند متوازن است و جمع کل‌ها == جمع ردیف‌ها
            var totalDeb = lines.Sum(l => l.Debit);
            var totalCred = lines.Sum(l => l.Credit);
            Assert.Equal(totalDeb, totalCred);
            Assert.Equal(totalDeb, rows.Where(r => r.Level == 0).Sum(r => r.Debit));
            Assert.Equal(totalCred, rows.Where(r => r.Level == 0).Sum(r => r.Credit));
        }

        /// <summary>دادهٔ بارگذاری‌شدهٔ سند + ساخت مدل چاپ (مثل دیالوگ).</summary>
        private sealed class LoadedDoc
        {
            public LoadedDoc(DocHeader header, List<DocumentLineRow> lines, List<RollupRow> rollup)
            {
                Header = header;
                Lines = lines;
                Kols = rollup.Where(r => r.Level == "Kol").Select(r => new AccountRollupRow
                {
                    Code = r.Code, Title = r.Title ?? "—",
                    LineCount = r.LineCount, Debit = r.Debit, Credit = r.Credit
                }).ToList();
                Moeins = rollup.Where(r => r.Level == "Moein").Select(r => new AccountRollupRow
                {
                    Code = r.Code, Title = r.Title ?? "—",
                    LineCount = r.LineCount, Debit = r.Debit, Credit = r.Credit
                }).ToList();
            }

            public DocHeader Header { get; }
            public List<DocumentLineRow> Lines { get; }
            public List<AccountRollupRow> Kols { get; }
            public List<AccountRollupRow> Moeins { get; }

            public AccountingDocumentPrintModel BuildModel() => new()
            {
                DocumentId = TargetDoc,
                DocumentNumber = Header.DocumentNumber,
                DocumentDate = Header.DocumentDate,
                DocumentType = Header.DocumentType,
                CounterPartyName = Header.CounterPartyName,
                TotalAmount = Header.TotalAmount,
                Status = Header.Status,
                Lines = Lines,
                Advanced = true,
                KolRows = Kols,
                MoeinRows = Moeins,
            };
        }

        private sealed class DocHeader
        {
            public int DocumentId { get; set; }
            public string DocumentNumber { get; set; } = "";
            public DateTime DocumentDate { get; set; }
            public string? DocumentType { get; set; }
            public string? CounterPartyName { get; set; }
            public decimal TotalAmount { get; set; }
            public string? Status { get; set; }
        }

        private sealed class RollupRow
        {
            public string Level { get; set; } = "";
            public string Code { get; set; } = "";
            public string? Title { get; set; }
            public int LineCount { get; set; }
            public decimal Debit { get; set; }
            public decimal Credit { get; set; }
        }
    }
}