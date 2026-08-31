using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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
/// گاردِ «همان بایت‌های دیزاینر»: دانلود PDF از دیزاینر چاپ
/// (<c>PrintDesigner.DownloadPdfAsync</c>) دقیقاً این مسیر را می‌رود:
///   ۱) قالبِ ذخیره‌شده از دیتابیس (همان <c>PrintTemplateService.GetAsync</c>)،
///   ۲) دادهٔ پیش‌نمایشِ معادل <c>BuildPreviewData()</c> (نمونه‌داده روشن)،
///   ۳) <c>BuildTemplatePdf(tpl, data)</c> **بدون** override اندازه — پس اندازه/جهت
///      از خودِ قالب (PaperSize/Orientation) می‌آید.
/// این تست همان بایت‌ها را برای همهٔ ترکیب‌های A4/A5 × عمودی/افقی (A5 افقی = A5L)
/// تولید و برون‌ریزی می‌کند تا با خروجی لایوِ UI مقایسه (هش) شود.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود (نه Fail).
/// </summary>
public class DesignerMatrixTests
{
    private const string TemplateId = "treasury.cheques";
    // شرکتِ فعالِ نشست admin در این دیتابیس شرکت ۳ است («شرکت تست») — نه شرکت ۱ که
    // soft-delete شده (IsDeleted=1) و CompanyAccountSettingsGet برایش null برمی‌گرداند.
    private const int CompanyId = 3;

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
    public async Task Designer_download_matrix_matches_reference_bytes()
    {
        using var probe = await TestDb.OpenOrSkipAsync();
        using var ensureCn = await TestDb.OpenOrSkipAsync();
        await TestDb.EnsurePrintingAsync(ensureCn);

        var catalog = new ScriptCatalog();
        var session = await NewSessionAsync(CompanyId, "شرکت تست");
        var db = new DbService(new FixedProvider(), catalog,
            new AuditService(new FixedProvider(), catalog, NullLogger<AuditService>.Instance),
            session, NullLogger<DbService>.Instance);
        var svc = new PdfReportService();

        // ── ۱) قالبِ ذخیره‌شده — دقیقاً همان مسیر دیزاینر (GetAsync → saved ?? default) ──
        var tplSvc = new PrintTemplateService(db, session);
        var tpl = await tplSvc.GetAsync(TemplateId) ?? PrintTemplates.Defaults.Get(TemplateId).Clone();
        Assert.NotNull(tpl);

        // ── ۱ب) تنظیمات شرکت — دقیقاً همان مسیر دیزاینر (CompanyAccountSettingsGet
        //      با ActiveCompanyId نشست). شرکتِ فعالِ admin شرکت ۳ است
        //      («شرکت تست» / «تهران سمت راست درب اول») — نه شرکت ۱ِ خالی.
        var company = await db.QueryFirstOrDefaultAsync<CompanyAccountSettingsRow>("accounting",
            "CompanyAccountSettingsGet", new { CompanyId = session.ActiveCompanyId });
        Assert.NotNull(company);

        // ── ۲) دادهٔ پیش‌نمایش — معادلِ BuildPreviewData() با نمونه‌دادهٔ روشن ──
        var data = BuildDesignerPreview(tpl, company!);

        var dir = Path.Combine(Path.GetTempPath(), "tarazin-pdf", "designer-matrix");
        Directory.CreateDirectory(dir);

        // ── ۳) همهٔ ترکیب‌های اندازه/جهت — بدون override، مثل دکمهٔ دانلود دیزاینر ──
        var combos = new (string Label, PrintPaperSize Size, PrintOrientation Orientation, double W, double H)[]
        {
            ("A4-P", PrintPaperSize.A4, PrintOrientation.Portrait, 595.28, 841.89),
            ("A4-L", PrintPaperSize.A4, PrintOrientation.Landscape, 841.89, 595.28),
            ("A5-P", PrintPaperSize.A5, PrintOrientation.Portrait, 419.53, 595.28),
            ("A5-L", PrintPaperSize.A5, PrintOrientation.Landscape, 595.28, 419.53),
        };

        var hashes = new List<string>();
        var reference = new Dictionary<string, string>();
        foreach (var (label, size, orientation, w, h) in combos)
        {
            var combo = tpl.Clone();
            combo.PaperSize = size;
            combo.Orientation = orientation;

            var bytes = svc.BuildTemplatePdf(combo, data);
            Assert.True(bytes.Length > 1000, $"[{label}] PDF too small: {bytes.Length}");

            // MediaBox باید با اندازه/جهت قالب هم‌خوان باشد (همان گارد A5L، ولی برای هر ۴ حالت)
            var geometry = PdfSurfaceGeometry.Check(bytes);
            Assert.InRange(geometry.PageWidth, w - 0.6, w + 0.6);
            Assert.InRange(geometry.PageHeight, h - 0.6, h + 0.6);
            if (orientation == PrintOrientation.Landscape)
                Assert.True(geometry.PageWidth > geometry.PageHeight, $"[{label}] باید landscape باشد");
            else
                Assert.True(geometry.PageWidth < geometry.PageHeight, $"[{label}] باید پرتره باشد");

            // بدون بیرون‌زدگی — محتوای واقعی درون MediaBox
            const double tol = 2.0;
            Assert.True(geometry.MaxDeviceX.HasValue && geometry.MaxDeviceY.HasValue,
                $"[{label}] هیچ محتوای قابل سنجشی نبود");
            Assert.InRange(geometry.MaxDeviceX!.Value, -tol, geometry.PageWidth + tol);
            Assert.InRange(geometry.MaxDeviceY!.Value, -tol, geometry.PageHeight + tol);
            Assert.True(geometry.MaxDeviceX.Value > 10, $"[{label}] MaxDeviceX محتوای واقعی نیست");

            var path = Path.Combine(dir, $"{TemplateId.Replace('.', '_')}-{label}.pdf");
            File.WriteAllBytes(path, bytes);
            var hash = StableHash(bytes);
            hashes.Add($"{label}\t{hash}");
            reference[label] = hash;
        }

        // ── ۴) گارد «هش چسبیده روی دو PDF» — شبیه‌سازی چند کلیک متوالی دانلود ──
        // باگ قبلی: دو دانلودِ پشت‌سرهمِ هم‌زمان در کلاینت با هم تداخل می‌کردند و فایل دوم
        // بایت‌های دانلودِ قبلی را می‌گرفت («هش روی دو PDF چسبیده» / نام فایل خراب).
        // اینجا همان مسیر بایت‌سازیِ دیزاینر (BuildTemplatePdf با قالبِ فعلی + دادهٔ پیش‌نمایش)
        // را با کلیک‌های متوالیِ درهم صدا می‌زنیم — ترکیب‌های متفاوت پشت‌سرهم + تکرارِ همان
        // ترکیب — و می‌سنجیم که هر کلیک دقیقاً هشِ خودش را بدهد نه هشِ کلیکِ قبلی.
        var clicks = new (string Label, PrintPaperSize Size, PrintOrientation Orientation)[]
        {
            ("A4-P", PrintPaperSize.A4, PrintOrientation.Portrait),
            ("A5-L", PrintPaperSize.A5, PrintOrientation.Landscape),
            ("A4-L", PrintPaperSize.A4, PrintOrientation.Landscape),
            ("A5-P", PrintPaperSize.A5, PrintOrientation.Portrait),
            // تکرارِ پشت‌سرهمِ یک ترکیب (dedupe در کلاینت) + تغییرِ ناگهانی به ترکیب دیگر:
            // همان نقطه‌ای که قبلاً چسب می‌خورد.
            ("A4-P", PrintPaperSize.A4, PrintOrientation.Portrait),
            ("A5-L", PrintPaperSize.A5, PrintOrientation.Landscape),
        };

        var clickHashes = new List<string>();
        for (var i = 0; i < clicks.Length; i++)
        {
            var (label, size, orientation) = clicks[i];
            var combo = tpl.Clone();
            combo.PaperSize = size;
            combo.Orientation = orientation;
            var bytes = svc.BuildTemplatePdf(combo, data);
            var hash = StableHash(bytes);

            // هر کلیک باید هشِ مرجعِ خودش را بدهد (تعیین‌پذیری + عدم چسبیدن به کلیک قبلی)
            Assert.Equal(reference[label], hash);
            clickHashes.Add(hash);
        }

        // هر دو کلیکِ متوالی با ترکیبِ متفاوت باید هشِ متفاوتی داشته باشند — اگر فایل دوم
        // بایت‌های کلیکِ قبلی را می‌گرفت، اینجا Fail می‌شد (هشِ چسبیده).
        for (var i = 1; i < clicks.Length; i++)
        {
            if (clicks[i].Label != clicks[i - 1].Label)
                Assert.NotEqual(clickHashes[i - 1], clickHashes[i]);
        }

        // چهار ترکیبِ متفاوت، چهار هشِ یکتا — هیچ دو ترکیبی هشِ مشترک ندارند.
        Assert.Equal(combos.Length, reference.Values.Distinct().Count());

        // مانيفست برای مقایسه با خروجی لایو UI (tools/compare-designer-downloads.sh)
        File.WriteAllLines(Path.Combine(dir, "sha256.txt"), hashes);
    }

    /// <summary>
    /// هشِ پایدارِ محتوای PDF (بدون تایم‌استمپ): QuestPDF در Info دیکشنریِ هر خروجی
    /// <c>CreationDate/ModDate</c> (با دقت ثانیه) می‌گذارد، پس هشِ خام بین دو اجرا — حتی
    /// برای محتوای کاملاً یکسان — همیشه فرق دارد. برای اینکه هش فقط به محتوای واقعی
    /// وابسته باشد، آن دو کلید را با مقدار ثابت جایگزین می‌کنیم. همین نرمال‌سازی باید
    /// در هر ابزار مقایسهٔ لایو (هش مرجع vs دانلود UI) هم به کار برود.
    /// </summary>
    private static string StableHash(byte[] bytes)
    {
        // Latin1 نگاشت ۱:۱ بایت→کاراکتر دارد، پس round-trip بدون تغییر است.
        var text = System.Text.Encoding.Latin1.GetString(bytes);
        var norm = System.Text.RegularExpressions.Regex.Replace(text,
            @"/CreationDate\s*\([^)]*\)|/ModDate\s*\([^)]*\)",
            "/CreationDate (D:0+00'00')/ModDate (D:0+00'00')");
        return Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.Latin1.GetBytes(norm)));
    }

    /// <summary>
    /// معادلِ <c>PrintDesigner.BuildPreviewData()</c> با <c>_showSample = true</c> —
    /// چون قالب چک‌ها متافیلدهای «بازه/وضعیت/شرکت» دارد، مقدار هر متافیلد طبق
    /// همان switch دیزاینر می‌شود: بازه→نمونه، وضعیت→یادداشت، شرکت→نمونه.
    /// </summary>
    private static PrintDataModel BuildDesignerPreview(PrintTemplateDef tpl, CompanyAccountSettingsRow company)
    {
        var data = new PrintDataModel
        {
            // دقیقاً مثل BuildPreviewData دیزاینر: نام/آدرس/لوگو از تنظیمات شرکتِ فعال؛
            // اگر خالی بود fallback همان متن دیزاینر.
            CompanyName = company.CompanyName ?? "ترازین — سامانه یکپارچه مدیریت کسب‌وکار",
            CompanyAddress = company.Address,
            LogoPath = company.LogoPath,
            Title = tpl.ReportTitle ?? tpl.Name,
            Subtitle = tpl.ReportSubtitle,
            RangeText = "بازه: 1405/06/01 تا 1405/06/31",
            QrPayload = $"tarazin:tpl:{tpl.Id}",
            QrEnabled = tpl.QrEnabled
        };

        for (var i = 0; i < tpl.MetaFields.Count; i++)
        {
            var f = tpl.MetaFields[i];
            // ⚠️ دقیقاً همان switch دیزاینر: ایندکس و برچسب **هر دو** شرط‌اند
            // (i==2 برای «وضعیت»، نه i==1). قالب چک‌ها [بازه، وضعیت، شرکت] است
            // → هر سه «نمونه» می‌شوند (با پیش‌نمایش لایو دیزاینر راست‌آزمایی شد).
            var value = (i, f.Label) switch
            {
                (0, { } l) when string.IsNullOrWhiteSpace(l) is false && l.Contains("شماره") => "00000018",
                (1, { } l) when string.IsNullOrWhiteSpace(l) is false && l.Contains("تاریخ") => "1405/06/06",
                (2, { } l) when string.IsNullOrWhiteSpace(l) is false && l.Contains("وضعیت") => "یادداشت",
                (3, { } l) when string.IsNullOrWhiteSpace(l) is false && l.Contains("نوع") => "فروش",
                (4, { } l) when string.IsNullOrWhiteSpace(l) is false && l.Contains("طرف") => "سارا رضایی",
                _ => "نمونه"
            };
            data.MetaFields.Add(new PrintMetaField { Label = f.Label, Value = value, Bold = f.Bold });
        }

        data.Rows.Add(new PrintRow { ["AccountCode"] = "2000", ["Title"] = "صندوق — دریافت نقدی", ["Debit"] = 20000000m, ["Credit"] = 0m });
        data.Rows.Add(new PrintRow { ["AccountCode"] = "1020", ["Title"] = "بانک — دریافت چک", ["Debit"] = 8000000m, ["Credit"] = 0m });
        data.Rows.Add(new PrintRow { ["AccountCode"] = "1010", ["Title"] = "فروش — فروش فروشگاه", ["Debit"] = 0m, ["Credit"] = 28000000m });
        data.FooterFields.Add(new PrintMetaField { Label = "تعداد ردیف", Value = data.Rows.Count.ToString(), Bold = true });
        return data;
    }

    private static async Task<UserSession> NewSessionAsync(int? companyId, string? companyName)
    {
        var session = new UserSession(Array.Empty<ISessionStore>(), Array.Empty<ICredentialSessionRevoker>());
        await session.SignInAsync(1, "diag", "diag",
            TarazinRoles.Admin, "مدیر سیستم", 1, null,
            companyId, companyName, null, null);
        return session;
    }
}
