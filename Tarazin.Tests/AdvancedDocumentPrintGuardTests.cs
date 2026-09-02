using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Tarazin.Models;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گارد ترتیبی چاپ پیشرفتهٔ سند با دادهٔ زندهٔ خودکفا: دیگر به سندِ ازپیش‌موجود
    /// (DocumentId=1547 در دیتابیس توسعه) وابسته نیست — خودش با اسکریپت واقعی UI
    /// (DocumentInsert.sql) یک سند ۳۲ ردیفه (کل ۱۰ ← معین ۱۰۰۰۰/۱۰۱۰۰ ← ۳۲ تفصیل)
    /// seed می‌کند و از همان اسکریپت‌های چاپ (DocumentById + DocumentLines +
    /// DocumentPrintRollup) بارگذاری می‌کند؛ پس روی **هر دیتابیس تازه** (از جمله CI با
    /// اسکیمای _Ensure) هم اجرا می‌شود نه اینکه Skip شود.
    /// قفل می‌کند که در مدل چاپ پیشرفته (Kol←Moein←تفصیل) هر تفصیل دقیقاً زیر معین
    /// خودش و هر معین زیر کل خودش بیاید و جمع هر سطح با جمع ردیف‌های زیرمجموعه‌اش برابر
    /// باشد. دو گارد: (۱) چیدمان دستی با همان قواعد GROUP BY اسکریپت، (۲) صدازدنِ خودِ
    /// <c>AdvancedDocRowsBuilder.Build</c> — همان متدی که DocumentPrintDialog و
    /// PdfReportService.BuildDocumentPdf هر دو استفاده می‌کنند (منبع واحد حقیقت).
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود.
    /// </summary>
    public class AdvancedDocumentPrintGuardTests
    {
        private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/accounting";

        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

        /// <summary>
        /// Seed و بارگذاری سند ۳۲ ردیفه در یک تراکنش: شرکت + سال مالی + دو حساب
        /// (کد ۱۰۰۰۰۰۰۰۰/۱۰۱۰۰۰۰۰۰ → کل ۱۰، معین ۱۰۰۰۰/۱۰۱۰۰) ساخته می‌شود و سپس
        /// DocumentInsert.sql واقعی ۱۶ بدهکار + ۱۶ بستانکار (هر طرف ۱۶٬۰۰۰٬۰۰۰، متوازن)
        /// ثبت می‌کند. سند با همان اسکریپت‌های UI بارگذاری می‌شود؛ همهٔ ردیف‌ها قبلاً در
        /// حافظه materialize شده‌اند، پس با پایان تراکنش (rollback) هیچ داده‌ای در DB نمی‌ماند
        /// و هیچ cleanup جداگانه‌ای لازم نیست.
        /// </summary>
        private static async Task<LoadedDoc> SeedAndLoadAsync(SqlConnection cn)
        {
            using var tx = cn.BeginTransaction();

            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست چاپ پیشرفته', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", transaction: tx);

            // مثل DbService.OpenConnectionAsync — بدون این، DEFAULT ستون CompanyId
            // ردیف‌های DocumentLines (fn_MobileCompanyId) به «اولین شرکت دیتابیس»
            // (مثلاً 3 در دیتابیس توسعه) می‌افتد نه شرکت seed شده؛ و چون rollup بر
            // CompanyId فیلتر می‌کند، روی دیتابیس‌های تازه/خالی گارد به‌اشتباه Fail
            // می‌شد. با ست کردن session context، ردیف‌ها دقیقاً شرکت seed شده را می‌گیرند.
            await cn.ExecuteAsync(
                "EXEC sys.sp_set_session_context @key=N'TarazinCompanyId', @value=@CompanyId;",
                new { CompanyId = compId }, transaction: tx);

            var fyId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
                VALUES (@c, N'1405', '2026-03-21', '2027-03-20', 1, N'Open', SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", new { c = compId }, transaction: tx);

            var accCash = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'100000000', N'صندوق', N'Asset', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId }, transaction: tx);

            var accBank = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'101000000', N'بانک', N'Asset', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId }, transaction: tx);

            // ۳۲ ردیف: ۱۶ بدهکار زیر معین ۱۰۰۰۰ + ۱۶ بستانکار زیر معین ۱۰۱۰۰ — متوازن
            var lines = new List<DocLineSeed>();
            for (var i = 1; i <= 16; i++)
            {
                lines.Add(new DocLineSeed { AccountId = accCash, AccountCode = "100000000", Description = $"بدهکار {i}", Debit = 1_000_000m, Credit = 0m });
                lines.Add(new DocLineSeed { AccountId = accBank, AccountCode = "101000000", Description = $"بستانکار {i}", Debit = 0m, Credit = 1_000_000m });
            }

            await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
            {
                LinesJson = JsonSerializer.Serialize(lines),
                DocumentDate = new DateTime(2026, 4, 5),
                DocumentType = "Journal",
                CounterPartyName = "شرکت نمونه",
                Status = "Draft",
                CreatedBy = "diag",
                CompanyId = compId,
                FiscalYearId = fyId,
                OverrideClosedYear = false,
                OverrideReason = (string?)null
            }, transaction: tx);

            var docId = await cn.ExecuteScalarAsync<int>(
                "SELECT TOP 1 DocumentId FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0 ORDER BY DocumentId DESC",
                new { c = compId }, transaction: tx);

            var header = await cn.QueryFirstOrDefaultAsync<DocHeader>(
                Script("DocumentById.sql"),
                new { DocumentId = docId, CompanyId = compId, FiscalYearId = fyId }, transaction: tx);
            Assert.NotNull(header);

            var docLines = (await cn.QueryAsync<DocumentLineRow>(
                Script("DocumentLines.sql"),
                new { DocumentId = docId, CompanyId = compId, FiscalYearId = fyId }, transaction: tx)).ToList();

            var rollup = (await cn.QueryAsync<RollupRow>(
                Script("DocumentPrintRollup.sql"),
                new { DocumentId = docId, CompanyId = compId }, transaction: tx)).ToList();

            Assert.Equal(32, docLines.Count); // سند seed شده باید دقیقاً 32 ردیف داشته باشد
            Assert.Contains(rollup, r => r.Level == "Kol" && r.Code == "10");
            Assert.Contains(rollup, r => r.Level == "Moein" && r.Code == "10000");
            Assert.Contains(rollup, r => r.Level == "Moein" && r.Code == "10100");

            return new LoadedDoc(header!, docLines, rollup);
        }

        /// <summary>ردیف سند برای JSON ورودی DocumentInsert (کلیدها با OPENJSON اسکریپت هم‌نام).</summary>
        private sealed class DocLineSeed
        {
            public int AccountId { get; set; }
            public string AccountCode { get; set; } = "";
            public string? Description { get; set; }
            public decimal Debit { get; set; }
            public decimal Credit { get; set; }
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
            var loaded = await SeedAndLoadAsync(cn);
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
            var loaded = await SeedAndLoadAsync(cn);
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
                DocumentId = Header.DocumentId,
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