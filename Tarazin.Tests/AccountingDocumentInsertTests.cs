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
    /// گاردِ بازگشت‌پذیر روی مسیر «ثبت سند» حسابداری (DocumentInsert.sql — REAL، نه mirror):
    ///  - ثبت سند متوازن دو ردیفی → سند با شمارهٔ خودکار، جمع، وضعیت و ردیف‌ها درست درج می‌شود.
    ///  - شماره‌گذاری خودکار: سند دوم در همان سال «00000002» می‌گیرد.
    ///  - اعتبارسنجی‌های سطح داده: نامتوازن (51041)، ردیف دونطرفه/خالی (51042)،
    ///    LinesJson خالی (51040) و حساب نامعتبر (51044) همگی رد می‌شوند.
    ///
    /// این همان مسیری است که فرم «ثبت سند» (AccountingEntry) با دکمهٔ «ثبت سند» صدا
    /// می‌زند؛ تست بدون مرورگر (مستقیم روی اسکریپت واقعی) انجام می‌شود.
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود تست Skip می‌شود.
    /// </summary>
    public class AccountingDocumentInsertTests
    {
        private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/accounting";

        /// <summary>نمایش ردیف سند ثبت‌شده (خروجی اسکریپت DocumentInsert + جدول Documents).</summary>
        private sealed record DocRow(string DocumentNumber, decimal TotalAmount, string Status, string DocumentType, string? CounterPartyName);

        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

        /// <summary>شرکت موقت + سال مالی باز + دو حساب (مسیر ChartOfAccounts کلاسیک).</summary>
        private static async Task<(int CompanyId, int FiscalYearId, int AccCash, int AccCust)> SeedAsync(SqlConnection cn)
        {
            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست ثبت سند', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var fyId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
                VALUES (@c, N'1405', '2026-03-21', '2027-03-20', 1, N'Open', SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", new { c = compId });

            var accCash = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'1010', N'صندوق تست', N'Asset', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });

            var accCust = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'2010', N'حساب مشتری تست', N'Liability', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });

            return (compId, fyId, accCash, accCust);
        }

        private static string BalancedJson(int accCash, int accCust, decimal amount = 500000m)
            => JsonSerializer.Serialize(new[]
            {
                new { AccountId = accCash, AccountCode = "1010", Description = "بدهکار", Debit = amount, Credit = 0m },
                new { AccountId = accCust, AccountCode = "2010", Description = "بستانکار", Debit = 0m, Credit = amount }
            });

        private static async Task CleanupAsync(SqlConnection cn, int compId)
        {
            await cn.ExecuteAsync(@"
                DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
                DELETE FROM accounting.Documents WHERE CompanyId=@c;
                DELETE FROM accounting.ChartOfAccounts WHERE CompanyId=@c;
                DELETE FROM central.FiscalYears WHERE CompanyId=@c;
                DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        }

        [SkippableFact]
        public async Task DocumentInsert_balanced_persists_document_number_lines()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, fyId, accCash, accCust) = await SeedAsync(cn);
            try
            {
                // سند متوازن: بدهکار 500,000 (صندوق) / بستانکار 500,000 (مشتری) — مثل فرم UI
                await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
                {
                    LinesJson = BalancedJson(accCash, accCust),
                    DocumentDate = new DateTime(2026, 4, 5),
                    DocumentType = "Journal",
                    CounterPartyName = "مشتری تست",
                    Status = "Draft",
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = fyId,
                    OverrideClosedYear = false,
                    OverrideReason = (string?)null
                });

                var doc = await cn.QuerySingleOrDefaultAsync<DocRow?>(@"
                    SELECT DocumentNumber, TotalAmount, [Status], DocumentType, CounterPartyName
                    FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0", new { c = compId });

                Assert.NotNull(doc);
                Assert.Equal("00000001", doc!.DocumentNumber);
                Assert.Equal(500000m, doc.TotalAmount);
                Assert.Equal("Draft", doc.Status);
                Assert.Equal("Journal", doc.DocumentType);
                Assert.Equal("مشتری تست", doc.CounterPartyName);

                var lines = (await cn.QueryAsync<dynamic>(@"
                    SELECT AccountCode, Description, Debit, Credit
                    FROM accounting.DocumentLines
                    WHERE DocumentId=(SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0)
                    ORDER BY Debit DESC", new { c = compId })).ToList();

                Assert.Equal(2, lines.Count);
                Assert.Contains(lines, l => l.Debit == 500000m && l.Credit == 0m && (string)l.AccountCode == "1010");
                Assert.Contains(lines, l => l.Credit == 500000m && l.Debit == 0m && (string)l.AccountCode == "2010");

                // سند دوم در همان سال → شمارهٔ بعدی 00000002
                await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
                {
                    LinesJson = BalancedJson(accCash, accCust, 250000m),
                    DocumentDate = new DateTime(2026, 4, 6),
                    DocumentType = "Journal",
                    CounterPartyName = "",
                    Status = "Note",
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = fyId,
                    OverrideClosedYear = false,
                    OverrideReason = (string?)null
                });

                var num2 = await cn.ExecuteScalarAsync<string>(
                    "SELECT DocumentNumber FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0 AND TotalAmount=250000",
                    new { c = compId });
                Assert.Equal("00000002", num2);

                // وضعیت Note هم باید حفظ شود
                var statusNote = await cn.ExecuteScalarAsync<string>(
                    "SELECT [Status] FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0 AND TotalAmount=250000",
                    new { c = compId });
                Assert.Equal("Note", statusNote);
            }
            finally
            {
                await CleanupAsync(cn, compId);
            }
        }

        [SkippableFact]
        public async Task DocumentInsert_rejects_unbalanced()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, fyId, accCash, accCust) = await SeedAsync(cn);
            try
            {
                var unbalanced = JsonSerializer.Serialize(new[]
                {
                    new { AccountId = accCash, AccountCode = "1010", Description = "x", Debit = 100m, Credit = 0m },
                    new { AccountId = accCust, AccountCode = "2010", Description = "x", Debit = 0m, Credit = 200m }
                });
                var err = await TryInsertAsync(cn, compId, fyId, unbalanced);
                Assert.Equal(51041, err);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task DocumentInsert_rejects_two_sided_row()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, fyId, accCash, accCust) = await SeedAsync(cn);
            try
            {
                // ردیفی که هم بدهکار و هم بستانکار دارد (مجموعِ متوازن: 100 بدهکار / 100 بستانکار) → 51042
                var json = JsonSerializer.Serialize(new[]
                {
                    new { AccountId = accCash, AccountCode = "1010", Description = "x", Debit = 100m, Credit = 100m },
                    new { AccountId = accCust, AccountCode = "2010", Description = "x", Debit = 0m, Credit = 0m }
                });
                var err = await TryInsertAsync(cn, compId, fyId, json);
                Assert.Equal(51042, err);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task DocumentInsert_rejects_empty_json()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, fyId, _, _) = await SeedAsync(cn);
            try
            {
                var err = await TryInsertAsync(cn, compId, fyId, "");
                Assert.Equal(51040, err);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task DocumentInsert_rejects_invalid_account()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, fyId, accCash, accCust) = await SeedAsync(cn);
            try
            {
                // AccountId 99999999 هیچ حسابی را resolve نمی‌کند → 51044
                var json = JsonSerializer.Serialize(new[]
                {
                    new { AccountId = 99999999, AccountCode = "1010", Description = "x", Debit = 100m, Credit = 0m },
                    new { AccountId = accCust, AccountCode = "2010", Description = "x", Debit = 0m, Credit = 100m }
                });
                var err = await TryInsertAsync(cn, compId, fyId, json);
                Assert.Equal(51044, err);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        /// <summary>اجرای DocumentInsert و بازگرداندن شمارهٔ خطای SQL در صورت THROW؛ -1 یعنی موفق.</summary>
        private static async Task<int> TryInsertAsync(SqlConnection cn, int compId, int fyId, string linesJson)
        {
            try
            {
                await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
                {
                    LinesJson = linesJson,
                    DocumentDate = new DateTime(2026, 4, 5),
                    DocumentType = "Journal",
                    CounterPartyName = "",
                    Status = "Draft",
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = fyId,
                    OverrideClosedYear = false,
                    OverrideReason = (string?)null
                });
                return -1;
            }
            catch (SqlException ex)
            {
                return ex.Number;
            }
        }
    }
}
