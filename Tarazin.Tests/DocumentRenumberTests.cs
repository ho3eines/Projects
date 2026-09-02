using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// سناریوی «شماره‌گذاری مجدد اسناد» — DocumentRenumber باید شماره‌های ۸رقمی
/// ترتیبی را به‌ترتیب تاریخ (و DocumentId در تاریخ مساوی) اختصاص دهد.
/// </summary>
public class DocumentRenumberTests
{
    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/accounting", name));

    private static async Task<(int CompanyId, int FiscalYearId)> SeedAsync(SqlConnection cn)
    {
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست شماره‌گذاری', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var fyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, IsDeleted, CreatedAt, CreatedBy, Status)
            VALUES (@c, N'سال ۱۴۰۵', N'2026-03-21', N'2027-03-20', 1, 0, SYSUTCDATETIME(), N'diag', N'Open');
            SELECT SCOPE_IDENTITY();", new { c = compId });

        return (compId, fyId);
    }

    private static async Task CleanupAsync(SqlConnection cn, int compId)
    {
        await cn.ExecuteAsync(@"
            DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
            DELETE FROM accounting.Documents WHERE CompanyId=@c;
            DELETE FROM central.FiscalYears WHERE CompanyId=@c;
            DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
    }

    /// <summary>سه سند با تاریخ‌های نامرتب → بعد از اجرا شماره‌ها 00000001/02/03 به‌ترتیب تاریخ‌اند.</summary>
    [SkippableFact]
    public async Task Renumber_assigns_sequential_numbers_ordered_by_date()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, fyId) = await SeedAsync(cn);
        try
        {
            // درج عمدی با تاریخ نامرتب: ۱۴۰۵/۰۳/۱۰ ، ۱۴۰۵/۰۱/۰۵ ، ۱۴۰۵/۰۲/۰۱ و شماره‌های اشتباه
            var dates = new[] { new DateTime(2026, 6, 10), new DateTime(2026, 4, 5), new DateTime(2026, 5, 1) };
            var numbers = new[] { "00000020", "00000010", "00000015" };
            foreach (var (d, n) in dates.Zip(numbers))
            {
                await cn.ExecuteAsync(@"
                    INSERT INTO accounting.Documents
                        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode,
                         Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
                    VALUES
                        (@n, @d, N'ManualEntry', N'تست', 1000, N'IRR', N'Note', N'diag', 0, @c, @fy);",
                    new { n = n, d = d, c = compId, fy = fyId });
            }

            var count = await cn.ExecuteScalarAsync<int>(Script("DocumentRenumber.sql"),
                new { CompanyId = compId, FiscalYearId = fyId, CreatedBy = "diag" });
            Assert.Equal(3, count);

            var rows = (await cn.QueryAsync<dynamic>(@"
                SELECT DocumentNumber, DocumentDate FROM accounting.Documents
                WHERE CompanyId=@c AND IsDeleted=0 ORDER BY DocumentNumber",
                new { c = compId })).ToList();

            Assert.Equal(3, rows.Count);
            Assert.Equal("00000001", (string)rows[0].DocumentNumber);
            Assert.Equal(new DateTime(2026, 4, 5), (DateTime)rows[0].DocumentDate);
            Assert.Equal("00000002", (string)rows[1].DocumentNumber);
            Assert.Equal(new DateTime(2026, 5, 1), (DateTime)rows[1].DocumentDate);
            Assert.Equal("00000003", (string)rows[2].DocumentNumber);
            Assert.Equal(new DateTime(2026, 6, 10), (DateTime)rows[2].DocumentDate);
        }
        finally { await CleanupAsync(cn, compId); }
    }
}
