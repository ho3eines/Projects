using System;
using System.IO;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گاردِ بازگشت‌پذیر روی مسیر «دریافت/پرداخت خزانه» (treasury.CashMovementInsert — REAL).
    /// همان مسیری که فرم «ثبت دریافت / پرداخت» (TreasuryEntry) با دکمهٔ «ثبت حرکت» صدا می‌زند:
    ///  - دریافت (In) به صندوق → حرکت CSH-…. + افزایش Balance صندوق.
    ///  - پرداخت (Out) از بانک → کاهش Balance حساب بانکی.
    ///  - جهت نامعتبر → خطای 51010.
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود تست Skip می‌شود.
    /// </summary>
    public class TreasuryCashMovementInsertTests
    {
        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/treasury", name));

        private static async Task<(int CompanyId, int CashBoxId, int BankAccountId)> SeedAsync(SqlConnection cn)
        {
            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست خزانه', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            // پاک‌سازی بقایای اجراهای قبلی که (معمولاً بعد از Crash) ناتمام مانده‌اند تا
            // seed ایدمپوتنت شود و ایندکس‌های یکتا این چند اجرای تست را نکوبند. CASCADE باید
            // دستی و با QUOTED_IDENTIFIER ON (sqlcmd -I) اجرا شود.
            await cn.ExecuteAsync(@"
                DELETE FROM treasury.CashMovements WHERE CashBoxId IN (SELECT CashBoxId FROM treasury.CashBoxes WHERE CashBoxCode=N'CB-1')
                                           OR AccountId   IN (SELECT AccountId   FROM treasury.BankAccounts WHERE AccountNo =N'1000');
                DELETE FROM treasury.CashBoxes     WHERE CashBoxCode=N'CB-1';
                DELETE FROM treasury.BankAccounts  WHERE AccountNo=N'1000';
                DELETE FROM treasury.Banks         WHERE BankCode=N'BK-TEST';");

            var bankId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO treasury.Banks (BankCode, Title, IsActive, IsDeleted) VALUES (N'BK-TEST', N'بانک تست', 1, 0);
                SELECT SCOPE_IDENTITY();");

            var accId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO treasury.BankAccounts (AccountName, AccountNo, BankId, Balance, IsActive, IsDeleted)
                VALUES (N'حساب تست', N'1000', @b, 0, 1, 0);
                SELECT SCOPE_IDENTITY();", new { b = bankId });

            var cashId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO treasury.CashBoxes (CashBoxCode, Title, Balance, IsActive, IsDeleted)
                VALUES (N'CB-1', N'صندوق تست', 0, 1, 0);
                SELECT SCOPE_IDENTITY();");

            // تنظیمات خزانه: IsEnabled=0 تا سند حسابداریِ خودکار درگیر نشود (تستِ خالصِ حرکت)
            await cn.ExecuteAsync(@"
                INSERT INTO treasury.TreasurySettings (CompanyId, IsEnabled, UpdatedAt)
                VALUES (@c, 0, SYSUTCDATETIME());", new { c = compId });

            return (compId, cashId, accId);
        }

        private static async Task CleanupAsync(SqlConnection cn, int compId)
        {
            await cn.ExecuteAsync(@"
                DELETE FROM treasury.CashMovements WHERE CompanyId=@c;
                DELETE FROM treasury.TreasurySettings WHERE CompanyId=@c;
                DELETE FROM treasury.CashBoxes WHERE CashBoxCode=N'CB-1';
                DELETE FROM treasury.BankAccounts WHERE AccountNo=N'1000';
                DELETE FROM treasury.Banks WHERE BankCode=N'BK-TEST';
                DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        }

        private static async Task<int> TryInsertAsync(
            SqlConnection cn, int compId, string direction, decimal amount,
            int? cashBoxId, int? accountId, string sourceRef)
        {
            try
            {
                await cn.ExecuteAsync(Script("CashMovementInsert.sql"), new
                {
                    Direction = direction,
                    MovementDate = new DateTime(2026, 4, 5),
                    Amount = amount,
                    CurrencyCode = "IRR",
                    AccountId = accountId,
                    CashBoxId = cashBoxId,
                    Description = "تست",
                    SourceReference = sourceRef,
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = (int?)null,
                    PartyId = (int?)null
                });
                return -1;
            }
            catch (SqlException ex) { return ex.Number; }
        }

        [SkippableFact]
        public async Task CashIn_updates_cashbox_and_movement()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, cashId, _) = await SeedAsync(cn);
            try
            {
                Assert.Equal(-1, await TryInsertAsync(cn, compId, "In", 1000000, cashId, null, "T-CASH-IN"));

                var mv = await cn.QuerySingleOrDefaultAsync<dynamic>(@"
                    SELECT MovementNumber, Direction, Amount, [Status]
                    FROM treasury.CashMovements WHERE CashBoxId=@cb", new { cb = cashId });
                Assert.NotNull(mv);
                Assert.StartsWith("CSH-", (string)mv.MovementNumber);
                Assert.Equal("In", (string)mv.Direction);
                Assert.Equal(1000000m, (decimal)mv.Amount);
                Assert.Equal("Posted", (string)mv.Status);

                var bal = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT Balance FROM treasury.CashBoxes WHERE CashBoxId=@cb", new { cb = cashId });
                Assert.Equal(1000000m, bal);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task CashOut_decreases_bank_balance()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, _, accId) = await SeedAsync(cn);
            try
            {
                Assert.Equal(-1, await TryInsertAsync(cn, compId, "Out", 500000, null, accId, "T-CASH-OUT"));

                var bal = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT Balance FROM treasury.BankAccounts WHERE AccountId=@a", new { a = accId });
                Assert.Equal(-500000m, bal);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task Invalid_direction_throws_51010()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, cashId, _) = await SeedAsync(cn);
            try
            {
                var rc = await TryInsertAsync(cn, compId, "X", 100, cashId, null, "T-BAD");
                Assert.Equal(51010, rc);
            }
            finally { await CleanupAsync(cn, compId); }
        }
    }
}