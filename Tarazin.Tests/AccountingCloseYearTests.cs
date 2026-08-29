using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گاردِ بازگشت‌پذیر روی زنجیرهٔ بستن سال مالی (با اسکریپت‌های REAL، نه mirror):
    ///  - ثبت سند در سال بسته بدون مجوز → خطای 51006
    ///  - ثبت با مجوز + دلیل → موفق و نوشتن ردیف ممیزی (central.AuditLog)
    ///  - بستن سال → سند اختتامیه + انتقال خودکار مانده‌ها به سند افتتاحیهٔ سال بعد
    ///
    /// سه باگ واقعی که این تست پیدا کرد:
    ///  1. `JSON_QUOTE` فقط در SQL Server 2025/Azure هست (نه 2022) → با CHAR(92)/CHAR(34) جایگزین شد.
    ///  2. `DECLARE @OverrideReason` همنام با پارامتر ورودی → خطای 134 → متغیر داخلی @Reason.
    ///  3. CASE های معکوس‌سازی مانده در DocumentClosingGenerate معکوس بودند → ماندهٔ منفی می‌ساختند.
    ///
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود (مثل CI) تست Skip می‌شود.
    /// </summary>
    public class AccountingCloseYearTests
    {
        [SkippableFact]
        public async Task CloseYear_chain_lock_override_carryover()
        {
            // SQL Server در دسترس نیست (مثلاً CI) → Skip نه Fail.
            using var cn = await TestDb.OpenOrSkipAsync();

            // 1) Throwaway company + fiscal years 1404/1405/1406
            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست بستن سال', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var fy1404 = await EnsureFy(cn, compId, "1404", new DateTime(2025, 3, 21), new DateTime(2026, 3, 20));
            var fy1405 = await EnsureFy(cn, compId, "1405", new DateTime(2026, 3, 21), new DateTime(2027, 3, 20));
            var fy1406 = await EnsureFy(cn, compId, "1406", new DateTime(2027, 3, 21), new DateTime(2028, 3, 19));

            // 1b) Give the throwaway company two ChartOfAccounts rows so DocumentInsert can resolve them.
            var accCash = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'1010', N'صندوق تست', N'Asset', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });
            var accCust = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'2010', N'حساب مشتری تست', N'Liability', 1, 0, SYSUTCDATETIME(), N'diag', @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });

            // 2) Post a normal journal document in 1405
            await cn.ExecuteAsync(@"
                INSERT INTO accounting.Documents (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, [Status], CreatedAt, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
                VALUES (N'00000001', '2026-04-05', N'Journal', N'مشتری تست', 1000000, N'IRR', N'Closed', SYSUTCDATETIME(), N'diag', 0, @c, @fy);
                DECLARE @docId INT = SCOPE_IDENTITY();
                INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
                VALUES (@docId, @cash, N'1010', N'صندوق', N'تست', 1000000, 0),
                       (@docId, @cust, N'2010', N'حساب مشتری', N'تست', 0, 1000000);",
                new { c = compId, fy = fy1405, cash = accCash, cust = accCust });

            // 3) Close 1404 (empty year -> just status flip) so the lock is testable
            await cn.ExecuteAsync(@"
                UPDATE central.FiscalYears SET [Status]=N'Closed', IsActive=1 WHERE FiscalYearId=@fy AND CompanyId=@c",
                new { fy = fy1404, c = compId });

            var linesJson = System.Text.Json.JsonSerializer.Serialize(new[]
            {
                new { AccountId = accCash, AccountCode = "1010", Description = "x", Debit = 100m, Credit = 0m },
                new { AccountId = accCust, AccountCode = "2010", Description = "x", Debit = 0m, Credit = 100m }
            });

            // 4) Try posting in closed 1404 WITHOUT override -> expect THROW 51006
            var noOverrideFailed = false;
            string noOverrideErr = "";
            try
            {
                await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
                {
                    LinesJson = linesJson,
                    DocumentDate = new DateTime(2025, 4, 5),
                    DocumentType = "Journal",
                    CounterPartyName = "مشتری تست",
                    Status = "Draft",
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = fy1404,
                    OverrideClosedYear = false,
                    OverrideReason = (string?)null
                });
            }
            catch (SqlException ex)
            {
                noOverrideFailed = ex.Number == 51006;
                noOverrideErr = $"#{ex.Number}: {ex.Message}";
            }
            Assert.True(noOverrideFailed, "expected 51006 when posting to closed year without override. got: " + noOverrideErr);

            // 5) Post WITH override + reason -> must succeed and write audit row
            long auditBefore = await cn.ExecuteScalarAsync<long>(
                "SELECT COUNT(*) FROM central.AuditLog WHERE CompanyId=@c", new { c = compId });
            await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
            {
                LinesJson = linesJson,
                DocumentDate = new DateTime(2025, 4, 5),
                DocumentType = "Journal",
                CounterPartyName = "مشتری تست",
                Status = "Draft",
                CreatedBy = "diag",
                CompanyId = compId,
                FiscalYearId = fy1404,
                OverrideClosedYear = true,
                OverrideReason = "اصلاح سند پایان دوره قبل"
            });
            long auditAfter = await cn.ExecuteScalarAsync<long>(
                "SELECT COUNT(*) FROM central.AuditLog WHERE CompanyId=@c", new { c = compId });
            Assert.True(auditAfter > auditBefore, "override must write an audit row");

            // 6) Now close 1405 -> closing doc + automatic opening doc in 1406 with carried balances
            var closing = await cn.QueryFirstOrDefaultAsync<dynamic>(
                Script("DocumentClosingGenerate.sql"), new
                {
                    CompanyId = compId,
                    FiscalYearId = fy1405,
                    CreatedBy = "diag"
                });
            Assert.NotNull(closing);
            Assert.Equal("Closing", (string)closing.DocumentType);

            var status1405 = await cn.ExecuteScalarAsync<string>(
                "SELECT [Status] FROM central.FiscalYears WHERE FiscalYearId=@fy", new { fy = fy1405 });
            Assert.Equal("Closed", status1405);

            var openingDoc = await cn.QueryFirstOrDefaultAsync<dynamic>(@"
                SELECT DocumentId FROM accounting.Documents
                WHERE CompanyId=@c AND FiscalYearId=@fy AND DocumentType=N'Opening' AND IsDeleted=0",
                new { fy = fy1406, c = compId });
            Assert.NotNull(openingDoc);

            var carried = await cn.QueryAsync<(string Code, decimal D, decimal C)>(@"
                SELECT AccountCode, Debit, Credit FROM accounting.DocumentLines WHERE DocumentId=@docId",
                new { docId = (int)openingDoc.DocumentId });
            Assert.Contains(carried, r => r.D == 1000000); // صندوق بدهکار منتقل شد
            Assert.Contains(carried, r => r.C == 1000000); // حساب مشتری بستانکار منتقل شد

            // 7) cleanup throwaway company (cascade)
            await cn.ExecuteAsync(@"
                DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
                DELETE FROM accounting.Documents WHERE CompanyId=@c;
                DELETE FROM accounting.ChartOfAccounts WHERE CompanyId=@c;
                DELETE FROM central.FiscalYears WHERE CompanyId=@c;
                DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        }

        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/accounting", name));

        private static async Task<int> EnsureFy(SqlConnection cn, int compId, string name, DateTime start, DateTime end)
        {
            var id = await cn.ExecuteScalarAsync<int>(@"
                IF EXISTS (SELECT 1 FROM central.FiscalYears WHERE CompanyId=@c AND YearName=@n AND IsDeleted=0)
                    SELECT FiscalYearId FROM central.FiscalYears WHERE CompanyId=@c AND YearName=@n AND IsDeleted=0;
                ELSE
                BEGIN
                    INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
                    VALUES (@c, @n, @s, @e, 1, N'Open', SYSUTCDATETIME(), N'diag');
                    SELECT SCOPE_IDENTITY();
                END",
                new { c = compId, n = name, s = start, e = end });
            return id;
        }
    }
}
