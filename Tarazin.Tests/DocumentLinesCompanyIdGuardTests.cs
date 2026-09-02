using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گارد مالکیت شرکتِ ردیف‌های سند: هر ردیف <c>accounting.DocumentLines</c> که از
/// مسیر واقعی UI (<c>DocumentInsert.sql</c>) ثبت می‌شود باید دقیقاً
/// <c>CompanyId</c> شرکتِ خودِ سند را بگیرد — نه «اولین شرکت دیتابیس».
///
/// چرا لازم است: ستون <c>DocumentLines.CompanyId</c> مقدار پیش‌فرض
/// <c>([central].[fn_MobileCompanyId]())</c> دارد که اول <c>SESSION_CONTEXT
/// ('TarazinCompanyId')</c> را می‌خواند و اگر نباشد به اولین شرکت دیتابیس
/// (<c>ORDER BY CompanyId</c>) می‌افتد. برنامه (DbService.OpenConnectionAsync)
/// همین context را در هر اتصال ست می‌کند؛ این گارد آن قرارداد را قفل می‌کند تا
/// اگر کسی ست‌کردن context را حذف کند یا پیش‌فرض/اسکریپت درج عوض شود، ردیف‌های
/// سندِ شرکتِ A بی‌صدا به شرکتِ B نچسبند (مشکل چندشرکتی).
///
/// برای معناداربودن روی هر دیتابیسی (حتی تازه/خالی): اول یک شرکت «اولِ» دِکوی
/// ساخته می‌شود تا fallbackِ تابع هرگز با شرکتِ real هم‌مقدار نشود؛ سپس شرکتِ
/// واقعی + سال مالی + حساب‌ها ساخته، context ست و سندِ واقعی ۲ ردیفی ثبت می‌شود
/// و تأیید می‌شود همهٔ ردیف‌ها CompanyId شرکتِ واقعی را دارند (و fallback نه).
/// همه‌چیز داخل یک تراکنش است که با پایان تست rollback می‌شود — هیچ داده‌ای در
/// DB باقی نمی‌ماند و نیازی به cleanup جداگانه نیست.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود.
/// </summary>
public class DocumentLinesCompanyIdGuardTests
{
    private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/accounting";

    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

    /// <summary>fallback تابع بدون session context (اولین شرکت دیتابیس) را می‌خواند.</summary>
    private static async Task<int?> FirstCompanyFallbackAsync(SqlConnection cn, SqlTransaction? tx)
    {
        var cmd = new CommandDefinition(
            "SELECT TOP 1 CompanyId FROM central.Companies WHERE IsDeleted = 0 ORDER BY CompanyId;",
            transaction: tx);
        return await cn.ExecuteScalarAsync<int?>(cmd);
    }

    [SkippableFact]
    public async Task DocumentInsert_lines_keep_own_company_not_first_company()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();

        // ── شرکت «اولِ» دِکوی — تضمین می‌کند fallback ≠ شرکتِ real حتی روی دیتابیس تازه ──
        var decoyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت اول دِکوی (گارد مالکیت)', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", transaction: tx);

        // ── شرکتِ واقعی + سال مالی + دو حساب ──
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست مالکیت ردیف', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", transaction: tx);
        Assert.True(compId != decoyId, "شرکت‌های دِکوی و واقعی باید متمایز باشند");

        var fyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
            VALUES (@c, N'1405', '2026-03-21', '2027-03-20', 1, N'Open', SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { c = compId }, transaction: tx);

        var accCash = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'1010', N'صندوق', N'Asset', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { c = compId }, transaction: tx);

        var accBank = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO accounting.ChartOfAccounts (AccountCode, Title, AccountType, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'2010', N'بانک', N'Liability', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { c = compId }, transaction: tx);

        // ── سنجهٔ fallback: بدون session context، تابع باید دِکوی را بدهد نه شرکتِ real ──
        var fallback = await FirstCompanyFallbackAsync(cn, tx);
        Assert.NotNull(fallback);
        Assert.True(fallback != compId,
            $"fallback تابع ({fallback}) نباید با شرکتِ real ({compId}) یکی باشد — گارد بی‌معنا می‌شود.");

        // ── مثل DbService.OpenConnectionAsync: ست‌کردن session context شرکتِ فعال ──
        await cn.ExecuteAsync(
            "EXEC sys.sp_set_session_context @key=N'TarazinCompanyId', @value=@CompanyId;",
            new { CompanyId = compId }, transaction: tx);

        // ── ثبت سندِ واقعی با همان مسیر UI (DocumentInsert.sql) ──
        var linesJson = JsonSerializer.Serialize(new[]
        {
            new { AccountId = accCash, AccountCode = "1010", Description = "بدهکار", Debit = 1_000_000m, Credit = 0m },
            new { AccountId = accBank, AccountCode = "2010", Description = "بستانکار", Debit = 0m, Credit = 1_000_000m }
        });
        await cn.ExecuteAsync(Script("DocumentInsert.sql"), new
        {
            LinesJson = linesJson,
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

        // ── گارد اصلی: هر ردیفِ سند باید CompanyId شرکتِ خودش را داشته باشد ──
        var rows = (await cn.QueryAsync<(int CompanyId, string AccountCode)>(@"
            SELECT l.CompanyId, l.AccountCode
            FROM accounting.DocumentLines l
            JOIN accounting.Documents d ON d.DocumentId = l.DocumentId
            WHERE d.CompanyId = @c AND d.IsDeleted = 0;",
            new { c = compId }, transaction: tx)).ToList();

        Assert.Equal(2, rows.Count); // سند ۲ ردیفی ثبت شده است
        Assert.All(rows, r => Assert.Equal(compId, r.CompanyId));
        Assert.DoesNotContain(rows, r => r.CompanyId == decoyId);
        Assert.All(rows, r => Assert.True(r.CompanyId != fallback,
            $"ردیف {r.AccountCode} به fallback ({fallback}) چسبیده است نه شرکتِ سند ({compId})."));
    }
}
