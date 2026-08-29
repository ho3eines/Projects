using System;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Tarazin.Data;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گاردِ SQL خالص (بدون سرویس/UI) روی اسکریپت‌های واقعی ماژول چاپ:
///   - Upsert: دامنه‌گذاری CompanyId، آزادسازیِ پیش‌فرض قبلیِ همان شرکت و سراسری،
///   - SetDefaultFor / ClearDefaultFor: رفتار مستقیم روی DefaultFor/CompanyId،
///   - GetByDefaultFor: اول قالبِ شرکتِ جاری → بعد قالبِ سراسری → null،
///   - ایندکس‌های یکتا: `UQ_PrintTemplates_DefaultFor_Company` (هر شرکت) و
///     `UQ_PrintTemplates_DefaultFor_Global` (سراسری) درجِ تکراری را رد می‌کنند.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود تست Skip می‌شود (نه Fail).
/// </summary>
public class PrintTemplateSqlGuardTests
{
    private const int CompanyA = 900011;
    private const int CompanyB = 900012;

    private static async Task<SqlConnection> SetupAsync()
    {
        var cn = await TestDb.OpenOrSkipAsync();
        await TestDb.EnsurePrintingAsync(cn);
        return cn;
    }

    private static async Task CleanupAsync(SqlConnection cn, string report, params string[] templateIds)
    {
        await cn.ExecuteAsync(@"
            DELETE FROM [printing].[PrintTemplates]
            WHERE [Id] IN @ids OR [DefaultFor] = @report;",
            new { ids = templateIds, report });
    }

    /// <summary>درج مستقیم (بدون Upsert) — برای تستِ خودِ ایندکسِ یکتا.</summary>
    private static Task<int> RawInsertAsync(SqlConnection cn, string id, string name, string? defaultFor, int? companyId)
        => cn.ExecuteAsync(@"
            INSERT INTO [printing].[PrintTemplates]
                ([Id], [Name], [Module], [PaperSize], [Orientation], [MarginMm], [FontSizePt],
                 [ShowCompanyHeader], [ShowPageFooter], [ShowReportFooter], [QrEnabled],
                 [ColumnsJson], [MetaJson], [IsSystem], [DefaultFor], [CompanyId])
            VALUES
                (@id, @name, N'test', N'A4', N'Portrait', 12, 9,
                 0, 0, 0, 0,
                 N'[]', N'[]', 0, @defaultFor, @companyId);",
            new { id, name, defaultFor, companyId });

    [SkippableFact]
    public async Task Upsert_scopes_company_and_frees_previous_defaults()
    {
        using var cn = await SetupAsync();
        var report = "test.upsert." + Guid.NewGuid().ToString("N")[..8];
        var t1 = "tpl.ups1." + Guid.NewGuid().ToString("N")[..8];
        var t2 = "tpl.ups2." + Guid.NewGuid().ToString("N")[..8];
        var tg = "tpl.upsg." + Guid.NewGuid().ToString("N")[..8];

        try
        {
            var catalog = new ScriptCatalog();
            Assert.True(catalog.TryGet("printing", "PrintTemplateUpsert", out var upsert), "PrintTemplateUpsert not found");

            // ۱) درج با DefaultFor → دامنهٔ شرکتِ جاری نوشته می‌شود
            await cn.ExecuteAsync(upsert, new
            {
                Id = t1, Name = "T1", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = report, CompanyId = CompanyA, UpdatedBy = "diag"
            });
            var row1 = await cn.QueryFirstAsync<(string DefaultFor, int? CompanyId)>(
                "SELECT DefaultFor, CompanyId FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = t1 });
            Assert.Equal(report, row1.DefaultFor);
            Assert.Equal(CompanyA, row1.CompanyId);

            // ۲) قالبِ دوم همان شرکتِ همان گزارش → اولی آزاد می‌شود (DefaultFor=NULL)
            await cn.ExecuteAsync(upsert, new
            {
                Id = t2, Name = "T2", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = report, CompanyId = CompanyA, UpdatedBy = "diag"
            });
            var freed1 = await cn.QueryFirstAsync<string?>(
                "SELECT DefaultFor FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = t1 });
            var holder = await cn.QueryFirstAsync<string?>(
                "SELECT DefaultFor FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = t2 });
            Assert.Null(freed1);
            Assert.Equal(report, holder);

            // ۳) پیش‌فرضِ سراسری (CompanyId NULL) — قالبِ شرکتِ A را آزاد نمی‌کند
            await cn.ExecuteAsync(upsert, new
            {
                Id = tg, Name = "TG", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = report, CompanyId = (int?)null, UpdatedBy = "diag"
            });
            var t2Still = await cn.QueryFirstAsync<string?>(
                "SELECT DefaultFor FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = t2 });
            Assert.Equal(report, t2Still); // قالبِ شرکتِ A دست‌نخورده ماند

            // ۴) دوباره پیش‌فرضِ شرکتِ A → سراسری آزاد می‌شود
            await cn.ExecuteAsync(upsert, new
            {
                Id = t1, Name = "T1", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = report, CompanyId = CompanyA, UpdatedBy = "diag"
            });
            var globalFreed = await cn.QueryFirstAsync<string?>(
                "SELECT DefaultFor FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = tg });
            Assert.Null(globalFreed); // سراسری آزاد شد

            // ۵) Upsert با DefaultFor خالی → CompanyId هم NULL می‌شود (قالب مشترک)
            await cn.ExecuteAsync(upsert, new
            {
                Id = t1, Name = "T1", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = "", CompanyId = CompanyA, UpdatedBy = "diag"
            });
            var shared = await cn.QueryFirstAsync<(string? DefaultFor, int? CompanyId)>(
                "SELECT DefaultFor, CompanyId FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = t1 });
            Assert.Null(shared.DefaultFor);
            Assert.Null(shared.CompanyId);
        }
        finally
        {
            await CleanupAsync(cn, report, t1, t2, tg);
        }
    }

    [SkippableFact]
    public async Task SetDefaultFor_and_ClearDefaultFor_manipulate_rows()
    {
        using var cn = await SetupAsync();
        var report = "test.setclear." + Guid.NewGuid().ToString("N")[..8];
        var ta = "tpl.sca." + Guid.NewGuid().ToString("N")[..8];
        var tb = "tpl.scb." + Guid.NewGuid().ToString("N")[..8];

        try
        {
            var catalog = new ScriptCatalog();
            Assert.True(catalog.TryGet("printing", "PrintTemplateUpsert", out var upsert), "PrintTemplateUpsert not found");
            Assert.True(catalog.TryGet("printing", "PrintTemplateSetDefaultFor", out var setDf), "PrintTemplateSetDefaultFor not found");
            Assert.True(catalog.TryGet("printing", "PrintTemplateClearDefaultFor", out var clearDf), "PrintTemplateClearDefaultFor not found");

            await cn.ExecuteAsync(upsert, new
            {
                Id = ta, Name = "TA", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = (string?)null, CompanyId = (int?)null, UpdatedBy = "diag"
            });
            await cn.ExecuteAsync(upsert, new
            {
                Id = tb, Name = "TB", Description = "", Module = "test",
                PaperSize = "A4", Orientation = "Portrait", MarginMm = 12, FontSizePt = 9f,
                ShowCompanyHeader = false, ShowPageFooter = false, ShowReportFooter = false, QrEnabled = false,
                ReportTitle = "", ReportSubtitle = "", ColumnsJson = "[]", MetaJson = "[]",
                IsSystem = false, DefaultFor = (string?)null, CompanyId = (int?)null, UpdatedBy = "diag"
            });

            // SetDefaultFor روی TA (شرکت A) → پیش‌فرضِ گزارش برای شرکت A
            await cn.ExecuteAsync(setDf, new { TemplateId = ta, ReportId = report, CompanyId = CompanyA, UpdatedBy = "diag" });
            var taRow = await cn.QueryFirstAsync<(string? DefaultFor, int? CompanyId)>(
                "SELECT DefaultFor, CompanyId FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = ta });
            Assert.Equal(report, taRow.DefaultFor);
            Assert.Equal(CompanyA, taRow.CompanyId);

            // SetDefaultFor روی TB (شرکت B) → پیش‌فرضِ شرکتِ A دست‌نخورده می‌ماند (ایزولاسیون)
            await cn.ExecuteAsync(setDf, new { TemplateId = tb, ReportId = report, CompanyId = CompanyB, UpdatedBy = "diag" });
            var taStill = await cn.QueryFirstAsync<(string? DefaultFor, int? CompanyId)>(
                "SELECT DefaultFor, CompanyId FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = ta });
            var tbRow = await cn.QueryFirstAsync<(string? DefaultFor, int? CompanyId)>(
                "SELECT DefaultFor, CompanyId FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = tb });
            Assert.Equal(report, taStill.DefaultFor);   // A دست‌نخورده
            Assert.Equal(CompanyA, taStill.CompanyId);
            Assert.Equal(report, tbRow.DefaultFor);     // B هم پیش‌فرضِ خودش را دارد
            Assert.Equal(CompanyB, tbRow.CompanyId);

            // SetDefaultFor روی TB با شرکتِ A (همان شرکتِ TA) → TA آزاد می‌شود، فقط TB می‌ماند
            await cn.ExecuteAsync(setDf, new { TemplateId = tb, ReportId = report, CompanyId = CompanyA, UpdatedBy = "diag" });
            var taFreed = await cn.QueryFirstAsync<string?>(
                "SELECT DefaultFor FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = ta });
            var tbNow = await cn.QueryFirstAsync<string?>(
                "SELECT DefaultFor FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = tb });
            Assert.Null(taFreed);           // قالبِ قبلیِ همان شرکت آزاد شد
            Assert.Equal(report, tbNow);    // TB تنها پیش‌فرضِ شرکت A شد

            // ClearDefaultFor → DefaultFor/CompanyId هر دو NULL (قالب دوباره مشترک)
            await cn.ExecuteAsync(clearDf, new { Id = tb, UpdatedBy = "diag" });
            var cleared = await cn.QueryFirstAsync<(string? DefaultFor, int? CompanyId)>(
                "SELECT DefaultFor, CompanyId FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = tb });
            Assert.Null(cleared.DefaultFor);
            Assert.Null(cleared.CompanyId);
        }
        finally
        {
            await CleanupAsync(cn, report, ta, tb);
        }
    }

    [SkippableFact]
    public async Task GetByDefaultFor_prefers_company_then_global_then_none()
    {
        using var cn = await SetupAsync();
        var report = "test.getdf." + Guid.NewGuid().ToString("N")[..8];
        var compA = "tpl.gda." + Guid.NewGuid().ToString("N")[..8];
        var compB = "tpl.gdb." + Guid.NewGuid().ToString("N")[..8];
        var global = "tpl.gdg." + Guid.NewGuid().ToString("N")[..8];

        try
        {
            // ردیف‌های مستقیم (بدون Upsert) — فقط GetByDefaultFor تست می‌شود
            await RawInsertAsync(cn, compA, "COMP-A", report, CompanyA);
            await RawInsertAsync(cn, global, "GLOBAL", report, null);

            // اسکریپت GetByDefaultFor اولین ستونِ SELECT یعنی [Id] را برمی‌گرداند —
            // پس مقدارِ برنده با شناسهٔ قالب مقایسه می‌شود.

            // ۱) شرکت A → قالبِ خودش (بر سراسری غلبه می‌کند)
            var forA = await QueryDefaultAsync(cn, report, CompanyA);
            Assert.Equal(compA, forA);

            // ۲) شرکت B (بدون قالبِ خودش) → قالبِ سراسری
            var forB = await QueryDefaultAsync(cn, report, CompanyB);
            Assert.Equal(global, forB);

            // ۳) شرکت B قالبِ خودش را دارد → خودش می‌گیرد
            await RawInsertAsync(cn, compB, "COMP-B", report, CompanyB);
            var forB2 = await QueryDefaultAsync(cn, report, CompanyB);
            Assert.Equal(compB, forB2);

            // ۴) هیچ ردیفی برای گزارشِ دیگر → null
            var other = await QueryDefaultAsync(cn, "test.getdf.none." + Guid.NewGuid().ToString("N")[..8], CompanyA);
            Assert.Null(other);
        }
        finally
        {
            await CleanupAsync(cn, report, compA, compB, global);
        }
    }

    /// <summary>
    /// بازنشانی در سطح SQL خالص: اجرای اسکریپت واقعیِ `PrintTemplateReset`
    /// (DELETE ردیفِ قالبِ پیش‌فرض) → وضوحِ GetByDefaultFor پله‌به‌پله پایین می‌آید:
    /// حذفِ پیش‌فرضِ شرکت → سراسری؛ حذفِ سراسری → خالی (null).
    /// </summary>
    [SkippableFact]
    public async Task Delete_default_row_falls_back_to_global_then_none()
    {
        using var cn = await SetupAsync();
        var report = "test.reset." + Guid.NewGuid().ToString("N")[..8];
        var compA = "tpl.rst.a." + Guid.NewGuid().ToString("N")[..8];
        var global = "tpl.rst.g." + Guid.NewGuid().ToString("N")[..8];

        try
        {
            var catalog = new ScriptCatalog();
            Assert.True(catalog.TryGet("printing", "PrintTemplateReset", out var reset), "PrintTemplateReset not found");

            // ۱) پیش‌فرضِ شرکت A + پیش‌فرضِ سراسری — هر دو فعال
            await RawInsertAsync(cn, compA, "COMP-A", report, CompanyA);
            await RawInsertAsync(cn, global, "GLOBAL", report, null);
            Assert.Equal(compA, await QueryDefaultAsync(cn, report, CompanyA));   // شرکت بر سراسری غلبه دارد
            Assert.Equal(global, await QueryDefaultAsync(cn, report, CompanyB));  // B → سراسری

            // ۲) بازنشانیِ پیش‌فرضِ شرکت (حذف ردیف با اسکریپت واقعی) → سراسری جایگزین می‌شود
            await cn.ExecuteAsync(reset, new { Id = compA });
            var compARows = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = compA });
            Assert.Equal(0, compARows);                                          // ردیف واقعاً حذف شده
            Assert.Equal(global, await QueryDefaultAsync(cn, report, CompanyA));  // fallback به سراسری

            // ۳) بازنشانیِ سراسری → دیگر هیچ پیش‌فرضی نیست → خالی (null)
            await cn.ExecuteAsync(reset, new { Id = global });
            var globalRows = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [printing].[PrintTemplates] WHERE [Id] = @id", new { id = global });
            Assert.Equal(0, globalRows);
            Assert.Null(await QueryDefaultAsync(cn, report, CompanyA));
            Assert.Null(await QueryDefaultAsync(cn, report, CompanyB));
        }
        finally
        {
            await CleanupAsync(cn, report, compA, global);
        }
    }

    /// <summary>
    /// هم‌زمانیِ SetDefaultFor: دو «نشست» برای یک گزارش — بازهٔ ازدست‌رفته (lost-update)
    /// بازسازی می‌شود: هر دو گامِ آزادسازی قبل از هر دو گامِ تنظیم اجرا می‌شوند
    /// (دقیقاً همان چیزی که دو تراکنشِ هم‌زمان می‌توانند بسازند). نتیجه: فقط یکی
    /// برنده است و ایندکسِ یکتا بازنده را با خطا رد می‌کند — هم برای دامنهٔ شرکت
    /// (UQ_PrintTemplates_DefaultFor_Company) و هم برای سراسری (UQ_PrintTemplates_DefaultFor_Global).
    /// گام‌های free/set از اسکریپتِ واقعیِ PrintTemplateSetDefaultFor استخراج می‌شوند (نه mirror).
    /// </summary>
    [SkippableFact]
    public async Task SetDefaultFor_concurrent_race_only_one_wins_unique_index_rejects_loser()
    {
        using var cn = await SetupAsync();
        var catalog = new ScriptCatalog();
        Assert.True(catalog.TryGet("printing", "PrintTemplateSetDefaultFor", out var full), "PrintTemplateSetDefaultFor not found");
        // دو گامِ اسکریپت واقعی: (۱) آزادسازیِ قبلی‌ها، (۲) تنظیمِ قالبِ هدف
        // ⚠️ جستجو case-sensitive است: «UPDATE» پیشوندِ «UPDATEDAT» است و IndexOf
        //    بدون حساسیت به حروف، داخلِ [UpdatedAt] را پیدا می‌کند و fragment را می‌شکند.
        var first = full.IndexOf("UPDATE", StringComparison.Ordinal);
        var second = full.IndexOf("UPDATE", first + 1, StringComparison.Ordinal);
        Assert.True(first >= 0 && second > first, "SetDefaultFor باید دو گام UPDATE داشته باشد");
        var freeStep = full.Substring(first, second - first);
        var setStep = full.Substring(second);

        // ── بخش ۱: دامنهٔ شرکت — دو قالبِ همان شرکت برای یک گزارش ──
        var report = "test.race." + Guid.NewGuid().ToString("N")[..8];
        var ta = "tpl.race.a." + Guid.NewGuid().ToString("N")[..8];
        var tb = "tpl.race.b." + Guid.NewGuid().ToString("N")[..8];
        try
        {
            await RawInsertAsync(cn, ta, "TA", null, CompanyA);
            await RawInsertAsync(cn, tb, "TB", null, CompanyA);

            // بازسازیِ بازهٔ ازدست‌رفته: هر دو «آزادسازی» قبل از هر دو «تنظیم»
            // (دو تراکنشِ هم‌زمان: هیچ‌کدام هنوز قالبِ دیگری را نمی‌بیند)
            await cn.ExecuteAsync(freeStep, new { ReportId = report, TemplateId = ta, CompanyId = CompanyA });
            await cn.ExecuteAsync(freeStep, new { ReportId = report, TemplateId = tb, CompanyId = CompanyA });
            await cn.ExecuteAsync(setStep, new { ReportId = report, TemplateId = ta, CompanyId = CompanyA, UpdatedBy = "diag" });
            var loser = await Assert.ThrowsAsync<SqlException>(() =>
                cn.ExecuteAsync(setStep, new { ReportId = report, TemplateId = tb, CompanyId = CompanyA, UpdatedBy = "diag" }));

            // بازنده با خطای ایندکسِ شرکت رد شد و فقط یک برنده می‌ماند
            Assert.Contains("UQ_PrintTemplates_DefaultFor_Company", loser.Message);
            var winnerId = await cn.QueryFirstOrDefaultAsync<string?>(
                "SELECT [Id] FROM [printing].[PrintTemplates] WHERE [DefaultFor] = @r AND [CompanyId] = @c",
                new { r = report, c = CompanyA });
            Assert.Equal(ta, winnerId);
            Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [printing].[PrintTemplates] WHERE [DefaultFor] = @r AND [CompanyId] = @c AND [Id] <> @ta",
                new { r = report, c = CompanyA, ta }));
        }
        finally
        {
            await CleanupAsync(cn, report, ta, tb);
        }

        // ── بخش ۲: سراسری — دو قالبِ بی‌شرکت برای یک گزارش ──
        var reportG = "test.race.g." + Guid.NewGuid().ToString("N")[..8];
        var tg1 = "tpl.race.g1." + Guid.NewGuid().ToString("N")[..8];
        var tg2 = "tpl.race.g2." + Guid.NewGuid().ToString("N")[..8];
        try
        {
            await RawInsertAsync(cn, tg1, "TG1", null, null);
            await RawInsertAsync(cn, tg2, "TG2", null, null);

            await cn.ExecuteAsync(freeStep, new { ReportId = reportG, TemplateId = tg1, CompanyId = (int?)null });
            await cn.ExecuteAsync(freeStep, new { ReportId = reportG, TemplateId = tg2, CompanyId = (int?)null });
            await cn.ExecuteAsync(setStep, new { ReportId = reportG, TemplateId = tg1, CompanyId = (int?)null, UpdatedBy = "diag" });
            var loserG = await Assert.ThrowsAsync<SqlException>(() =>
                cn.ExecuteAsync(setStep, new { ReportId = reportG, TemplateId = tg2, CompanyId = (int?)null, UpdatedBy = "diag" }));

            Assert.Contains("UQ_PrintTemplates_DefaultFor_Global", loserG.Message);
            var winnerG = await cn.QueryFirstOrDefaultAsync<string?>(
                "SELECT [Id] FROM [printing].[PrintTemplates] WHERE [DefaultFor] = @r AND [CompanyId] IS NULL",
                new { r = reportG });
            Assert.Equal(tg1, winnerG);
        }
        finally
        {
            await CleanupAsync(cn, reportG, tg1, tg2);
        }
    }

    [SkippableFact]
    public async Task Unique_indexes_reject_duplicate_default_for_same_company_and_global()
    {
        using var cn = await SetupAsync();
        var report = "test.uniq." + Guid.NewGuid().ToString("N")[..8];
        var t1 = "tpl.uq1." + Guid.NewGuid().ToString("N")[..8];
        var t2 = "tpl.uq2." + Guid.NewGuid().ToString("N")[..8];
        var t3 = "tpl.uq3." + Guid.NewGuid().ToString("N")[..8];
        var t4 = "tpl.uq4." + Guid.NewGuid().ToString("N")[..8];

        try
        {
            // ۱) دو پیش‌فرض برای همان شرکت + همان گزارش → ایندکسِ شرکت رد می‌کند
            await RawInsertAsync(cn, t1, "T1", report, CompanyA);
            var dupCompany = await Assert.ThrowsAsync<SqlException>(() => RawInsertAsync(cn, t2, "T2", report, CompanyA));
            Assert.Contains("UQ_PrintTemplates_DefaultFor_Company", dupCompany.Message);

            // ۲) دو پیش‌فرضِ سراسری برای همان گزارش → ایندکسِ سراسری رد می‌کند
            await RawInsertAsync(cn, t3, "T3", report, null);
            var dupGlobal = await Assert.ThrowsAsync<SqlException>(() => RawInsertAsync(cn, t4, "T4", report, null));
            Assert.Contains("UQ_PrintTemplates_DefaultFor_Global", dupGlobal.Message);

            // ۳) همان گزارش ولی شرکتِ متفاوت → مجاز است (کلید یکتای per-company)
            var otherCompany = await RawInsertAsync(cn, "tpl.uq5." + Guid.NewGuid().ToString("N")[..8], "T5", report, CompanyB);
            Assert.Equal(1, otherCompany);
        }
        finally
        {
            await CleanupAsync(cn, report, t1, t2, t3, t4);
        }
    }

    private static async Task<string?> QueryDefaultAsync(SqlConnection cn, string reportId, int companyId)
    {
        var catalog = new ScriptCatalog();
        Assert.True(catalog.TryGet("printing", "PrintTemplateGetByDefaultFor", out var get), "PrintTemplateGetByDefaultFor not found");
        return await cn.QueryFirstOrDefaultAsync<string?>(get, new { ReportId = reportId, CompanyId = companyId });
    }
}
