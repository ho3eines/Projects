using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گاردِ بازگشت‌پذیر روی زنجیرهٔ کامل سرتاسری سند حسابداری (با اسکریپت‌های REAL، نه mirror):
    ///   ۱. ثبت سند   ← accounting.DocumentInsert
    ///   ۲. تأیید سند  ← accounting.DocumentStatusChange (یادداشت → موقت → تأیید‌شده)
    ///   ۳. بستن دوره   ← accounting.DocumentPeriodClose (موقت→تأیید‌شده → تأیید نهایی)
    ///   ۴. بستن سال   ← accounting.DocumentClosingGenerate (سند اختتامیه + انتقال مانده به سند افتتاحیهٔ سال بعد)
    ///
    /// هر مرحله فقط با ابزار تخصیص‌یافته‌اش و طبق قواعد (یک‌گامی بودن انتقال وضعیت،
    /// ممنوعیت تغییر سند در سال بسته،…) انجام می‌شود — همین زنجیره همان چیزی است که
    /// اپراتور/مدیر در UI با دکمهٔ «ثبت سند»، «تأیید»، «بستن دوره» و «بستن سال» انجام می‌دهد.
    ///
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود (مثل CI) تست Skip می‌شود.
    /// </summary>
    public class AccountingFullChainTests
    {
        private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/accounting";

        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

        // ── Seed مشترک: شرکت موقت + دو سال مالی (سال جاریِ باز و سال بعد) + دو حساب ──
        private static async Task<(int CompanyId, int FyThis, int FyNext, int AccCash, int AccLiability)>
            SeedAsync(SqlConnection cn)
        {
            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست زنجیرهٔ کامل', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var fyThis = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
                VALUES (@c, N'1405', '2026-03-21', '2027-03-20', 1, N'Open', SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", new { c = compId });

            var fyNext = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
                VALUES (@c, N'1406', '2027-03-21', '2028-03-19', 1, N'Open', SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", new { c = compId });

            var accCash = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'1010', N'صندوق تست', N'Asset', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });

            var accLiab = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'2010', N'حساب پرداختنی تست', N'Liability', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });

            return (compId, fyThis, fyNext, accCash, accLiab);
        }

        private static async Task CleanupAsync(SqlConnection cn, int compId)
        {
            await cn.ExecuteAsync(@"
                DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
                DELETE FROM accounting.Documents WHERE CompanyId=@c;
                DELETE FROM accounting.ChartOfAccounts WHERE CompanyId=@c;
                DELETE FROM central.AuditLog WHERE CompanyId=@c;
                DELETE FROM central.FiscalYears WHERE CompanyId=@c;
                DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        }

        private static (int DocumentId, string Number) GetDoc(SqlConnection cn, int compId, int fyId)
        {
            return cn.QuerySingleOrDefault<(int, string)>(
                @"SELECT DocumentId, DocumentNumber FROM accounting.Documents WHERE CompanyId=@c AND FiscalYearId=@fy AND IsDeleted=0 AND DocumentType=N'Journal'",
                new { c = compId, fy = fyId });
        }

        /// <summary>اجرای DocumentInsert و بازگرداندن شمارهٔ خطای SQL؛ -1 یعنی موفق.</summary>
        private static async Task<int> TryInsertAsync(
            SqlConnection cn, int compId, int fyId, string linesJson, string status, DateTime date)
        {
            try
            {
                await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
                {
                    LinesJson = linesJson,
                    DocumentDate = date,
                    DocumentType = "Journal",
                    CounterPartyName = "مشتری زنجیره",
                    Status = status,
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = fyId,
                    OverrideClosedYear = false,
                    OverrideReason = (string?)null
                });
                return -1;
            }
            catch (SqlException ex) { return ex.Number; }
        }

        /// <summary>اجرای DocumentStatusChange و بازگرداندن شمارهٔ خطای SQL؛ -1 یعنی موفق.</summary>
        private static async Task<int> TryStatusChangeAsync(
            SqlConnection cn, int compId, int fyId, int docId, string? expected, string target)
        {
            try
            {
                await cn.ExecuteAsync(Script("DocumentStatusChange.sql"), new
                {
                    DocumentId = docId,
                    CompanyId = compId,
                    FiscalYearId = fyId,
                    ExpectedStatus = expected,
                    NewStatus = target,
                    UpdatedBy = "diag"
                });
                return -1;
            }
            catch (SqlException ex) { return ex.Number; }
        }

        private static async Task<string> GetStatusAsync(SqlConnection cn, int docId)
            => await cn.ExecuteScalarAsync<string>(
                "SELECT [Status] FROM accounting.Documents WHERE DocumentId=@d", new { d = docId });

        [SkippableFact]
        public async Task FullChain_register_approve_closePeriod_closeYear_carryover()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, fyThis, fyNext, accCash, accLiab) = await SeedAsync(cn);
            try
            {
                // ───────────────── ۱) ثبت سند (یادداشت) ─────────────────
                const decimal amount = 1_000_000m;
                var linesJson = JsonSerializer.Serialize(new[]
                {
                    new { AccountId = accCash, AccountCode = "1010", Description = "بدهکار صندوق", Debit = amount, Credit = 0m },
                    new { AccountId = accLiab, AccountCode = "2010", Description = "بستانکار پرداختنی", Debit = 0m, Credit = amount }
                });
                var rcInsert = await TryInsertAsync(cn, compId, fyThis, linesJson, "Note", new DateTime(2026, 4, 5));
                Assert.Equal(-1, rcInsert);

                var (docId, docNumber) = GetDoc(cn, compId, fyThis);
                Assert.Equal("00000001", docNumber);
                Assert.Equal("Note", await GetStatusAsync(cn, docId));

                // ───────────────── ۲) تأیید: فقط یک گام در چرخه مجاز است ─────────────────
                // پرش دوگامی (یادداشت → تأییدشده) رد می‌شود → 51050
                Assert.Equal(51050, await TryStatusChangeAsync(cn, compId, fyThis, docId, "Note", "Posted"));

                // یادداشت → موقت
                Assert.Equal(-1, await TryStatusChangeAsync(cn, compId, fyThis, docId, "Note", "Draft"));
                Assert.Equal("Draft", await GetStatusAsync(cn, docId));

                // سندِ نامتوازن نمی‌تواند به «تأییدشده» برسد → 51041
                // (فقط برای اطمینان: ردیف‌های سند متوازن‌اند، پس این رد نمی‌شود؛ تستِ رد جدا در DocumentInsertTests هست)
                Assert.Equal(-1, await TryStatusChangeAsync(cn, compId, fyThis, docId, "Draft", "Posted"));
                Assert.Equal("Posted", await GetStatusAsync(cn, docId));

                // ───────────────── ۳) بستن دوره: تأییدشده → تأیید نهایی ─────────────────
                var rcPeriod = await cn.ExecuteAsync(Script("DocumentPeriodClose.sql"), new
                {
                    FromDate = new DateTime(2026, 4, 1),
                    ToDate = new DateTime(2026, 4, 30),
                    CompanyId = compId,
                    FiscalYearId = fyThis,
                    CreatedBy = "diag"
                });
                Assert.Equal(1, rcPeriod); // دقیقاً یک سند بسته شد
                Assert.Equal("Closed", await GetStatusAsync(cn, docId));

                // ───────────────── ۴) بستن سال: سند اختتامیه + انتقال مانده ─────────────────
                var closing = await cn.QueryFirstOrDefaultAsync<dynamic>(
                    Script("DocumentClosingGenerate.sql"),
                    new { CompanyId = compId, FiscalYearId = fyThis, CreatedBy = "diag" });

                Assert.NotNull(closing);
                Assert.Equal("Closing", (string)closing.DocumentType);
                Assert.Equal(amount, (decimal)closing.TotalAmount);

                // سال جاری بسته شد
                var fyStatus = await cn.ExecuteScalarAsync<string>(
                    "SELECT [Status] FROM central.FiscalYears WHERE FiscalYearId=@fy", new { fy = fyThis });
                Assert.Equal("Closed", fyStatus);

                // سند افتتاحیهٔ سال بعد ساخته شد و مانده‌ها منتقل شدند (بدهکار صندوق / بستانکار پرداختنی)
                var openingDoc = await cn.QueryFirstOrDefaultAsync<dynamic>(@"
                    SELECT DocumentId FROM accounting.Documents
                    WHERE CompanyId=@c AND FiscalYearId=@fy AND DocumentType=N'Opening' AND IsDeleted=0",
                    new { fy = fyNext, c = compId });
                Assert.NotNull(openingDoc);

                var carried = (await cn.QueryAsync<(string Code, decimal D, decimal C)>(@"
                    SELECT AccountCode, Debit, Credit FROM accounting.DocumentLines WHERE DocumentId=@docId",
                    new { docId = (int)openingDoc.DocumentId })).ToList();

                Assert.Contains(carried, r => r.D == amount && r.C == 0m && r.Code == "1010"); // صندوق بدهکار
                Assert.Contains(carried, r => r.C == amount && r.D == 0m && r.Code == "2010"); // پرداختنی بستانکار

                // ───────────────── ۵) سال بسته: تغییر وضعیت سند در سال بسته ممنوع است → 51006 ─────────────────
                Assert.Equal(51006, await TryStatusChangeAsync(cn, compId, fyThis, docId, "Closed", "Posted"));

                // ثبت سند تازه در سال بسته (بدون مجوز) → 51006
                Assert.Equal(51006, await TryInsertAsync(cn, compId, fyThis, linesJson, "Note", new DateTime(2026, 4, 6)));
            }
            finally
            {
                await CleanupAsync(cn, compId);
            }
        }
    }
}