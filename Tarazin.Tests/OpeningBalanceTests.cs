using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// سناریوی «مانده ابتدای دوره (Opening Balance)» — صفحهٔ /accounting/opening
/// روی سند افتتاحیه کار می‌کند: DocumentOpeningEnsure (ساخت/بازیابی اتمیک) و
/// سپس DocumentUpdate برای ثبت ردیف‌های مانده. این تست همان مسیر را پوشش می‌دهد.
/// </summary>
public class OpeningBalanceTests
{
    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/accounting", name));

    private static async Task<(int CompanyId, int FiscalYearId, int Acct101, int Acct201)> SeedAsync(SqlConnection cn)
    {
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست افتتاحیه', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var fyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, IsDeleted, CreatedAt, CreatedBy, Status)
            VALUES (@c, N'سال ۱۴۰۵', N'2026-03-21', N'2027-03-20', 1, 0, SYSUTCDATETIME(), N'diag', N'Open');
            SELECT SCOPE_IDENTITY();", new { c = compId });

        // دو حساب با کد کوتاه (مسیر legacyExact در DocumentUpdate)
        var acct101 = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted)
            VALUES (N'101', N'صندوق', N'Asset', 1, 0); SELECT SCOPE_IDENTITY();");
        var acct201 = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted)
            VALUES (N'201', N'سرمایه', N'Equity', 1, 0); SELECT SCOPE_IDENTITY();");

        return (compId, fyId, acct101, acct201);
    }

    private static async Task CleanupAsync(SqlConnection cn, int compId, params int[] accountIds)
    {
        await cn.ExecuteAsync(@"
            DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
            DELETE FROM accounting.Documents WHERE CompanyId=@c;
            DELETE FROM central.FiscalYears WHERE CompanyId=@c;
            DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        foreach (var id in accountIds)
            await cn.ExecuteAsync("DELETE FROM accounting.ChartOfAccounts WHERE AccountId=@id", new { id });
    }

    /// <summary>
    /// DocumentOpeningEnsure: ساخت سند افتتاحیهٔ 00000001، idempotent بودن،
    /// و سپس ثبت ردیف‌های مانده با DocumentUpdate (نوع سند Opening حفظ می‌شود).
    /// </summary>
    [SkippableFact]
    public async Task Opening_ensure_is_idempotent_and_lines_update_persist()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, fyId, acct101, acct201) = await SeedAsync(cn);
        try
        {
            var opening = (await cn.QueryAsync<dynamic>(Script("DocumentOpeningEnsure.sql"),
                new { CompanyId = compId, FiscalYearId = fyId, CreatedBy = "diag" })).First();
            var openingId = (int)opening.DocumentId;
            Assert.True(openingId > 0);
            Assert.Equal("00000001", (string)opening.DocumentNumber);
            Assert.Equal("Opening", (string)opening.DocumentType);

            // Idempotent: فراخوانی مجدد همان سند را برمی‌گرداند، سند دوم نمی‌سازد.
            var again = (await cn.QueryAsync<dynamic>(Script("DocumentOpeningEnsure.sql"),
                new { CompanyId = compId, FiscalYearId = fyId, CreatedBy = "diag" })).First();
            Assert.Equal(openingId, (int)again.DocumentId);

            var count = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM accounting.Documents WHERE CompanyId=@c AND DocumentType=N'Opening' AND IsDeleted=0",
                new { c = compId });
            Assert.Equal(1, count);

            // ثبت مانده: صندوق ۵٬۰۰۰٬۰۰۰ بدهکار / سرمایه ۵٬۰۰۰٬۰۰۰ بستانکار
            var linesJson = System.Text.Json.JsonSerializer.Serialize(new[]
            {
                new { AccountId = acct101, AccountCode = "101", Description = "ماندهٔ افتتاحیه صندوق", Debit = 5000000m, Credit = 0m },
                new { AccountId = acct201, AccountCode = "201", Description = "ماندهٔ افتتاحیه سرمایه", Debit = 0m, Credit = 5000000m }
            });

            await cn.ExecuteAsync(Script("DocumentUpdate.sql"), new
            {
                DocumentId = openingId,
                LinesJson = linesJson,
                DocumentDate = new DateTime(2026, 3, 21),
                DocumentType = "Opening",
                CounterPartyName = (string?)null,
                UpdatedBy = "diag",
                CompanyId = compId,
                FiscalYearId = fyId
            });

            var doc = (await cn.QueryAsync<dynamic>(
                "SELECT DocumentType, TotalAmount FROM accounting.Documents WHERE DocumentId=@id",
                new { id = openingId })).First();
            Assert.Equal("Opening", (string)doc.DocumentType);
            Assert.Equal(5000000m, (decimal)doc.TotalAmount);

            var lines = (await cn.QueryAsync<dynamic>(
                "SELECT AccountCode, Debit, Credit FROM accounting.DocumentLines WHERE DocumentId=@id ORDER BY AccountCode",
                new { id = openingId })).ToList();
            Assert.Equal(2, lines.Count);
            Assert.Equal("101", (string)lines[0].AccountCode);
            Assert.Equal(5000000m, (decimal)lines[0].Debit);
            Assert.Equal("201", (string)lines[1].AccountCode);
            Assert.Equal(5000000m, (decimal)lines[1].Credit);
        }
        finally { await CleanupAsync(cn, compId, acct101, acct201); }
    }
}
