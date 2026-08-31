using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging.Abstractions;
using Tarazin.Data;
using Tarazin.Models;
using Tarazin.Services;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گاردِ ترتیب وضوح قالب چاپ در <c>PrintTemplateService.GetOrCreateDefaultAsync</c>:
///   ۱) قالب ذخیره‌شده با همان شناسهٔ گزارش (پوشش مستقیم)،
///   ۲) قالبِ «پیش‌فرض» گزارش (DefaultFor) — اول قالبِ شرکتِ جاری، بعد قالبِ سراسری،
///   ۳) قالب پیش‌فرض داخلی (تعریف‌شده در کد).
/// هم‌راه با ایزولاسیون شرکت: پیش‌فرضِ یک شرکت نباید به شرکتِ دیگر نشت کند.
///
/// از اسکریپت‌های REAL (printing.*) و سرویس واقعی استفاده می‌شود، نه mirror.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود تست Skip می‌شود (نه Fail).
/// </summary>
public class PrintTemplateResolutionTests
{
    /// <summary>اتصال ثابت به دیتابیس تست — برای DbService (بدون نیاز به DI کامل هاست).</summary>
    private sealed class FixedProvider : ISqlConnectionProvider
    {
        public bool IsAvailable => true;
        public string Description => "test-provider";
        public bool SupportsInitialization => false;
        public string DatabaseName => "TarazinMaster";

        public ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct = default) => OpenAsync();
        public ValueTask<SqlConnection> OpenMasterConnectionAsync(CancellationToken ct = default) => OpenAsync();

        private static async ValueTask<SqlConnection> OpenAsync()
        {
            var cn = new SqlConnection(TestDb.ConnectionString);
            await cn.OpenAsync();
            return cn;
        }
    }

    [SkippableFact]
    public async Task Resolution_order_direct_then_defaultfor_then_builtin()
    {
        // SQL Server در دسترس نیست (مثلاً CI) → Skip نه Fail.
        using var probe = await TestDb.OpenOrSkipAsync();

        var catalog = new ScriptCatalog();
        // شناسهٔ گزارش و قالب‌های یک‌بارمصرف — هیچ دادهٔ واقعی لمس نمی‌شود.
        var reportId = "test.resolution." + Guid.NewGuid().ToString("N")[..8];
        var compAId = "tpl.a." + Guid.NewGuid().ToString("N")[..8];
        var compBId = "tpl.b." + Guid.NewGuid().ToString("N")[..8];
        var globalId = "tpl.global." + Guid.NewGuid().ToString("N")[..8];
        const int companyA = 900001;
        const int companyB = 900002;

        // 0) اطمینان از وجود schema/جدول قالب‌ها — اجرای اسکریپت واقعی و idempotent
        using var ensureCn = await TestDb.OpenOrSkipAsync();
        await TestDb.EnsurePrintingAsync(ensureCn);

        // نشست‌ها: شرکت A، شرکت B، و نشستِ بی‌شرکت (برای ساخت پیش‌فرضِ سراسری)
        var sessionA = await NewSessionAsync(companyA, "شرکت A");
        var sessionB = await NewSessionAsync(companyB, "شرکت B");
        var sessionGlobal = await NewSessionAsync(null, null);

        var svcA = NewService(sessionA, catalog);
        var svcB = NewService(sessionB, catalog);
        var svcGlobal = NewService(sessionGlobal, catalog);

        try
        {
            // ── ۱) مرحلهٔ ۳: بدون هیچ ردیفی → قالب پیش‌فرض داخلی (Generic برای شناسهٔ ناشناخته)
            var builtIn = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal(reportId, builtIn.Id);
            Assert.Equal($"قالب پیش‌فرض — {reportId}", builtIn.Name);

            // ── ۲) مرحلهٔ ۱: قالبِ مستقیم با همان شناسهٔ گزارش بر همه چیز غلبه می‌کند
            await svcA.SaveAsync(Tpl(reportId, "DIRECT-REPORT", null));
            var direct = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("DIRECT-REPORT", direct.Name);

            // بازنشانیِ قالب مستقیم → ردیف حذف → دوباره مرحلهٔ ۳
            await svcA.ResetToDefaultAsync(reportId);
            var afterReset = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal($"قالب پیش‌فرض — {reportId}", afterReset.Name);

            // ── ۳) پیش‌فرضِ سراسری (CompanyId NULL): شرکتی که پیش‌فرض خودش را ندارد آن را می‌گیرد
            await svcGlobal.SaveAsync(Tpl(globalId, "GLOBAL-DEFAULT", reportId)); // نشستِ بی‌شرکت → CompanyId NULL
            var global = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("GLOBAL-DEFAULT", global.Name);

            // ── ۴) پیش‌فرضِ شرکتِ جاری بر سراسری غلبه می‌کند
            //     (Upsert هنگام تنظیم پیش‌فرضِ یک شرکت، پیش‌فرضِ سراسریِ همان گزارش را هم آزاد می‌کند)
            await svcA.SaveAsync(Tpl(compAId, "COMP-A-DEFAULT", reportId));
            var compA = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("COMP-A-DEFAULT", compA.Name);

            // ── ۵) ایزولاسیون شرکت: شرکت B پیش‌فرضِ A را نمی‌بیند
            //     (سراسری هم توسط مرحلهٔ ۴ آزاد شده → به قالب داخلی می‌افتد)
            var compBIsolated = await svcB.GetOrCreateDefaultAsync(reportId);
            Assert.Equal($"قالب پیش‌فرض — {reportId}", compBIsolated.Name);

            // ── ۶) سراسری دوباره ساخته شد → شرکت B (بدون پیش‌فرض خودش) آن را می‌گیرد
            //     (آزادسازیِ سراسری فقط ردیف‌های NULL را می‌زند؛ پیش‌فرضِ A دست‌نخورده می‌ماند)
            await svcGlobal.SaveAsync(Tpl(globalId, "GLOBAL-DEFAULT", reportId));
            var compBSeesGlobal = await svcB.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("GLOBAL-DEFAULT", compBSeesGlobal.Name);

            // ── ۷) شرکت B پیش‌فرضِ خودش را دارد → بر سراسری غلبه می‌کند
            await svcB.SaveAsync(Tpl(compBId, "COMP-B-DEFAULT", reportId));
            var compB = await svcB.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("COMP-B-DEFAULT", compB.Name);

            // شرکت A هنوز پیش‌فرضِ خودش را دارد (هیچ‌کدام از مراحلِ B/سراسری آن را عوض نکرده)
            var compAAgain = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("COMP-A-DEFAULT", compAAgain.Name);
        }
        finally
        {
            // پاک‌سازی کامل — فقط ردیف‌های تست (شناسه‌های یک‌بارمصرف) حذف می‌شوند
            using var cn = await TestDb.OpenOrSkipAsync();
            await cn.ExecuteAsync(@"
                DELETE FROM [printing].[PrintTemplates]
                WHERE [Id] IN (@reportId, @compAId, @compBId, @globalId)
                   OR [DefaultFor] = @reportId;",
                new { reportId, compAId, compBId, globalId });
        }
    }

    /// <summary>
    /// بازنشانی (`ResetToDefaultAsync`) روی قالبِ پیش‌فرضِ شرکت → وضوح پله‌به‌پله
    /// به‌سمت پایین برمی‌گردد (نه یک‌راست به قالب داخلی):
    ///   شرکتِ A (پیش‌فرضِ خودش + سراسری فعال) → بازنشانیِ پیش‌فرضِ شرکت → سراسری؛
    ///   بازنشانیِ سراسری → قالب داخلی؛
    ///   دوباره پیش‌فرضِ شرکت + قالب مستقیم → بازنشانیِ مستقیم → پیش‌فرضِ شرکت؛
    ///   بازنشانیِ پیش‌فرضِ شرکت → قالب داخلی.
    /// </summary>
    [SkippableFact]
    public async Task Reset_falls_back_to_global_then_builtin()
    {
        // SQL Server در دسترس نیست (مثلاً CI) → Skip نه Fail.
        using var probe = await TestDb.OpenOrSkipAsync();

        var catalog = new ScriptCatalog();
        var reportId = "test.reset." + Guid.NewGuid().ToString("N")[..8];
        var compAId = "tpl.rsa." + Guid.NewGuid().ToString("N")[..8];
        var globalId = "tpl.rsg." + Guid.NewGuid().ToString("N")[..8];
        const int companyA = 900021;

        using var ensureCn = await TestDb.OpenOrSkipAsync();
        await TestDb.EnsurePrintingAsync(ensureCn);

        var sessionA = await NewSessionAsync(companyA, "شرکت A");
        var sessionGlobal = await NewSessionAsync(null, null);
        var svcA = NewService(sessionA, catalog);
        var svcGlobal = NewService(sessionGlobal, catalog);

        try
        {
            // ۱) پیش‌فرضِ شرکت A و بعد سراسری — سراسریِ بعدی قالبِ شرکت را آزاد نمی‌کند
            //    (تنظیمِ سراسری فقط ردیف‌های NULL را می‌زند)، پس هر دو فعال‌اند.
            await svcA.SaveAsync(Tpl(compAId, "COMP-A-DEFAULT", reportId));
            await svcGlobal.SaveAsync(Tpl(globalId, "GLOBAL-DEFAULT", reportId));
            var before = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("COMP-A-DEFAULT", before.Name); // شرکت بر سراسری غلبه دارد

            // ۲) بازنشانیِ پیش‌فرضِ شرکت → ردیف حذف → وضوح به سراسری می‌افتد
            await svcA.ResetToDefaultAsync(compAId);
            Assert.Null(await svcA.GetAsync(compAId));          // ردیف واقعاً حذف شده
            var afterCompanyReset = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("GLOBAL-DEFAULT", afterCompanyReset.Name);

            // ۳) بازنشانیِ سراسری → دیگر هیچ پیش‌فرضی نیست → قالب داخلی
            await svcA.ResetToDefaultAsync(globalId);
            Assert.Null(await svcA.GetAsync(globalId));
            var afterGlobalReset = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal($"قالب پیش‌فرض — {reportId}", afterGlobalReset.Name);

            // ۴) دوباره پیش‌فرضِ شرکت + قالب مستقیم (شناسه = گزارش) → مستقیم برنده است
            await svcA.SaveAsync(Tpl(compAId, "COMP-A-DEFAULT", reportId));
            await svcA.SaveAsync(Tpl(reportId, "DIRECT-REPORT", null));
            Assert.Equal("DIRECT-REPORT", (await svcA.GetOrCreateDefaultAsync(reportId)).Name);

            // ۵) بازنشانیِ قالب مستقیم → ردیفِ مستقیم حذف → وضوح به پیش‌فرضِ شرکت برمی‌گردد
            //    (نه یک‌راست به قالب داخلی)
            await svcA.ResetToDefaultAsync(reportId);
            Assert.Null(await svcA.GetAsync(reportId));
            var afterDirectReset = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal("COMP-A-DEFAULT", afterDirectReset.Name);

            // ۶) بازنشانیِ پیش‌فرضِ شرکت → هیچ ردیفی نیست → قالب داخلی
            await svcA.ResetToDefaultAsync(compAId);
            Assert.Null(await svcA.GetAsync(compAId));
            var final = await svcA.GetOrCreateDefaultAsync(reportId);
            Assert.Equal($"قالب پیش‌فرض — {reportId}", final.Name);
        }
        finally
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            await cn.ExecuteAsync(@"
                DELETE FROM [printing].[PrintTemplates]
                WHERE [Id] IN (@reportId, @compAId, @globalId)
                   OR [DefaultFor] = @reportId;",
                new { reportId, compAId, globalId });
        }
    }

    /// <summary>
    /// رفتارِ per-company تابعِ <c>SetDefaultForAsync</c> (سطح سرویس، نه اسکریپت خام):
    /// دو شرکتِ متفاوت برای **همان گزارش** هر کدام قالبِ پیش‌فرضِ جدا و مستقل می‌گیرند،
    /// هیچ‌کدام پیش‌فرضِ دیگری را آزاد/بازنویسی نمی‌کند، و ایندکسِ یکتای
    /// (CompanyId, DefaultFor) در عمل برقرار می‌ماند — هر دو ردیف هم‌زمان در DB
    /// (DefaultFor یکسان ولی CompanyId متفاوت) بدون هیچ خطای ایندکس ذخیره می‌شوند
    /// و هر نشست دقیقاً قالبِ خودش را از وضوح برمی‌گرداند.
    /// </summary>
    [SkippableFact]
    public async Task SetDefaultFor_is_per_company_two_defaults_coexist_unique_index_holds()
    {
        // SQL Server در دسترس نیست (مثلاً CI) → Skip نه Fail.
        using var probe = await TestDb.OpenOrSkipAsync();

        var catalog = new ScriptCatalog();
        // همان گزارش برای هر دو شرکت — تفاوت فقط در دامنهٔ شرکت است
        var reportId = "test.perco." + Guid.NewGuid().ToString("N")[..8];
        var tplA = "tpl.pca." + Guid.NewGuid().ToString("N")[..8];
        var tplB = "tpl.pcb." + Guid.NewGuid().ToString("N")[..8];
        const int companyA = 900031;
        const int companyB = 900032;

        using var ensureCn = await TestDb.OpenOrSkipAsync();
        await TestDb.EnsurePrintingAsync(ensureCn);

        var sessionA = await NewSessionAsync(companyA, "شرکت A");
        var sessionB = await NewSessionAsync(companyB, "شرکت B");
        var svcA = NewService(sessionA, catalog);
        var svcB = NewService(sessionB, catalog);

        try
        {
            // ۱) هر شرکت قالبِ خودش را می‌سازد (بدون پیش‌فرض اولیه)
            await svcA.SaveAsync(Tpl(tplA, "COMP-A-TPL", null));
            await svcB.SaveAsync(Tpl(tplB, "COMP-B-TPL", null));

            // ۲) هر شرکت همان گزارش را روی قالبِ خودش «پیش‌فرض» می‌کند
            await svcA.SetDefaultForAsync(tplA, reportId);
            await svcB.SetDefaultForAsync(tplB, reportId);

            // ۳) ایندکس یکتای (CompanyId, DefaultFor) در عمل برقرار می‌ماند:
            //    دو ردیف با DefaultFor یکسان ولی CompanyId متفاوت هم‌زمان ذخیره می‌شوند
            //    (بدون خطای UQ) — یعنی وضوحِ هر شرکت از قالبِ خودش می‌آید نه از شرکتِ دیگر.
            using var cn = await TestDb.OpenOrSkipAsync();
            var rows = (await cn.QueryAsync<(string Id, int? CompanyId)>(
                "SELECT [Id], [CompanyId] FROM [printing].[PrintTemplates] " +
                "WHERE [DefaultFor] = @r ORDER BY [CompanyId]", new { r = reportId })).ToList();
            Assert.Equal(2, rows.Count);
            Assert.Contains((tplA, (int?)companyA), rows);
            Assert.Contains((tplB, (int?)companyB), rows);

            // ۴) ایزولاسیون در عمل: وضوحِ هر شرکت دقیقاً قالبِ خودش را برمی‌گرداند
            Assert.Equal("COMP-A-TPL", (await svcA.GetOrCreateDefaultAsync(reportId)).Name);
            Assert.Equal("COMP-B-TPL", (await svcB.GetOrCreateDefaultAsync(reportId)).Name);

            // ۵) تنظیمِ پیش‌فرض در شرکت B، پیش‌فرضِ شرکت A را آزاد/بازنویسی نکرده
            //    (دوباره‌تنظیمِ B روی قالبِ خودش → A دست‌نخورده می‌ماند)
            await svcB.SetDefaultForAsync(tplB, reportId);
            Assert.Equal("COMP-A-TPL", (await svcA.GetOrCreateDefaultAsync(reportId)).Name);

            // ۶) برعکس: تنظیمِ A هم پیش‌فرضِ B را دست نمی‌زند
            await svcA.SetDefaultForAsync(tplA, reportId);
            Assert.Equal("COMP-B-TPL", (await svcB.GetOrCreateDefaultAsync(reportId)).Name);

            // ۷) هنوز هر دو ردیفِ پیش‌فرضِ هم‌زمان سر جایش هستند — ایندکس سالم است
            var still = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [printing].[PrintTemplates] WHERE [DefaultFor] = @r", new { r = reportId });
            Assert.Equal(2, still);
        }
        finally
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            await cn.ExecuteAsync(@"
                DELETE FROM [printing].[PrintTemplates]
                WHERE [Id] IN (@tplA, @tplB)
                   OR [DefaultFor] = @reportId;",
                new { tplA, tplB, reportId });
        }
    }

    private static async Task<UserSession> NewSessionAsync(int? companyId, string? companyName)
    {
        var session = new UserSession(Array.Empty<ISessionStore>(), Array.Empty<ICredentialSessionRevoker>());
        await session.SignInAsync(1, "diag", "diag",
            TarazinRoles.Admin, "مدیر سیستم", 1, null,
            companyId, companyName, null, null);
        return session;
    }

    private static PrintTemplateService NewService(UserSession session, ScriptCatalog catalog)
    {
        var provider = new FixedProvider();
        var db = new DbService(provider, catalog,
            new AuditService(provider, catalog, NullLogger<AuditService>.Instance),
            session, NullLogger<DbService>.Instance);
        return new PrintTemplateService(db, session);
    }

    /// <summary>قالب حداقلی برای ذخیره — فقط Id/Name/DefaultFor مهم‌اند.</summary>
    private static PrintTemplateDef Tpl(string id, string name, string? defaultFor) => new()
    {
        Id = id,
        Name = name,
        Description = "قالب تست ترتیب وضوح",
        Module = "test",
        PaperSize = PrintPaperSize.A4,
        Orientation = PrintOrientation.Portrait,
        MarginMm = 12,
        FontSizePt = 9,
        ShowCompanyHeader = false,
        ShowPageFooter = false,
        ShowReportFooter = false,
        QrEnabled = false,
        IsSystem = false,
        DefaultFor = defaultFor,
        Columns = new List<PrintColumnDef>
        {
            new() { Key = "Description", Title = "شرح", Width = 100, Align = PrintAlign.Start }
        },
        MetaFields = new List<PrintMetaField>()
    };
}
