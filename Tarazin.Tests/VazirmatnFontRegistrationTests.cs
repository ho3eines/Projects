using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Tarazin.Services;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گارد ثبت فونت Vazirmatn در موتور رندر PDF (QuestPDF) — همان مسیری که استارتاپ
/// (Web + MAUI) از <c>AddTarazinUiServices</c> صدا می‌زند.
///
/// اگر کسی TTF را از EmbeddedResource حذف کند، LogicalName را عوض کند یا
/// <c>Register()</c> را از مسیر استارتاپ بردارد، یکی از تست‌های زیر fail می‌شود.
/// (نکته: اگر روی دستگاهی که Vazirmatn به‌صورت فونت سیستمی نصب است، تست رندر با
/// BaseFont هنوز پاس می‌ماند؛ تست منابع جاسازی‌شده همان مورد را می‌گیرد.)
/// </summary>
public class VazirmatnFontRegistrationTests
{
    private static Assembly UiAssembly => typeof(VazirmatnFontRegistrar).Assembly;

    [Fact]
    public void Register_embeds_vazirmatn_ttf_as_embedded_resources()
    {
        foreach (var name in new[]
                 {
                     "Tarazin.Ui.fonts.Vazirmatn-Regular.ttf",
                     "Tarazin.Ui.fonts.Vazirmatn-Bold.ttf"
                 })
        {
            using var stream = UiAssembly.GetManifestResourceStream(name);
            Assert.True(stream is not null, $"منبع جاسازی‌شدهٔ {name} باید موجود باشد.");
            Assert.True(stream!.Length > 0, $"منبع {name} نباید خالی باشد.");
        }
    }

    [Fact]
    public void Register_is_idempotent_and_questpdf_embeds_vazirmatn_basefont()
    {
        QuestPDF.Settings.License = LicenseType.Community;

        // دوبار اجرا: idempotent است و نباید خطا بدهد.
        VazirmatnFontRegistrar.Register();
        VazirmatnFontRegistrar.Register();

        // رندر سند مینیمال با خانوادهٔ «Vazirmatn» — اگر فونت resolve نشود (ثبت شکسته
        // یا TTF حذف شده)، QuestPDF به فونت پیش‌فرض (Lato/SegoeUI) برمی‌گردد و
        // BaseFont فونتِ رندر شدهٔ Vazirmatn نخواهد بود.
        var bytes = Document.Create(doc =>
        {
            doc.Page(page =>
            {
                page.Size(PageSizes.A5);
                page.Margin(10);
                page.DefaultTextStyle(x => x.FontFamily(VazirmatnFontRegistrar.FamilyName).FontSize(10));
                page.Content().Text("متن آزمایشی فونت Vazirmatn — ترازین");
            });
        }).GeneratePdf();

        Assert.True(bytes.Length > 0, "PDF باید تولید شده باشد.");

        var ascii = Encoding.ASCII.GetString(bytes);
        Assert.Contains("/BaseFont", ascii, StringComparison.Ordinal);
        Assert.Contains("Vazirmatn", ascii, StringComparison.OrdinalIgnoreCase);

        // فونت fallback نباید به‌جای Vazirmatn بنشیند — یعنی BaseFont رندر باید
        // خانوادهٔ خواسته‌شده را جاسازی کرده باشد، نه Lato/SegoeUI را.
        var vaz = ascii.IndexOf("Vazirmatn", StringComparison.OrdinalIgnoreCase);
        Assert.True(vaz >= 0, "BaseFont باید حاوی Vazirmatn باشد.");
    }

    /// <summary>
    /// گارد «گزارش BI واقعی»: تعریف واقعی گزارش «فروش روزانه طلا» از کاتالوگ BI را با
    /// مسیرِ همان صفحهٔ /bi/reports (BiPrintFactory → BuildTemplatePdf) رندر می‌کند،
    /// سپس BaseFont واقعیِ جاسازی‌شدهٔ PDF را می‌خواند و تأیید می‌کند که
    /// <c>GetFontSourceInfo</c> نام «Vazirmatn» و منبع «embedded» را برمی‌گرداند
    /// (نه فالتبک Lato/SegoeUI).
    /// </summary>
    [Fact]
    public void GetFontSourceInfo_real_bi_report_is_vazirmatn_embedded()
    {
        QuestPDF.Settings.License = LicenseType.Community;
        VazirmatnFontRegistrar.Register();

        var def = BiReportCatalog.Reports.First(r => r.Key == "gold");
        var rows = new List<dynamic>
        {
            Dict("GINV-0001", "مشتری الف", "گلد ۱۸ عیار", 12.5m, 150000m, 80000m, 7500000m),
            Dict("GINV-0002", "مشتری ب", "گلد ۱۸ عیار", 8.2m, 90000m, 45000m, 4900000m),
            Dict("GINV-0003", "مشتری ج", "زنجیر", 15.0m, 200000m, 100000m, 9000000m)
        };
        var tpl = BiPrintFactory.BuildTemplate(def, rows.Count);
        var data = BiPrintFactory.BuildData(def, rows, new DateTime(2026, 8, 23), new DateTime(2026, 8, 25));

        var bytes = new PdfReportService().BuildTemplatePdf(tpl, data);
        Assert.True(bytes.Length > 0, "گزارش BI واقعی باید PDF تولید کند.");

        // BaseFont واقعی PDF باید Vazirmatn جاسازی‌شده باشد — نه لِتین فالتبک.
        var ascii = Encoding.ASCII.GetString(bytes);
        Assert.Contains("Vazirmatn", ascii, StringComparison.OrdinalIgnoreCase);

        // نام و منبع گزارش‌شده برای UI/گارد باید «Vazirmatn» + «embedded» باشد.
        var info = VazirmatnFontRegistrar.GetFontSourceInfo("Vazirmatn");
        Assert.Equal("Vazirmatn", info.Name);
        Assert.Equal("embedded", info.Source);
        Assert.True(info.IsEmbedded);
        Assert.Contains("embedded", info.Label, StringComparison.Ordinal);
    }

    /// <summary>
    /// حالت فالتبک: هر نام فونت غیر-Vazirmatn (Lato/SegoeUI — همان‌هایی که QuestPDF
    /// در نبود ثبت‌کننده به آن‌ها برمی‌گردد) باید «fallback» شناخته شود تا UI بتواند
    /// برچسب درست «فالتبک» را نمایش دهد.
    /// </summary>
    [Theory]
    [InlineData("Lato")]
    [InlineData("SegoeUI")]
    [InlineData("Helvetica")]
    [InlineData(null)]
    public void GetFontSourceInfo_non_vazirmatn_is_marked_fallback(string? fontName)
    {
        var info = VazirmatnFontRegistrar.GetFontSourceInfo(fontName);
        Assert.Equal("fallback", info.Source);
        Assert.False(info.IsEmbedded);
        Assert.Contains("fallback", info.Label, StringComparison.Ordinal);
    }

    private static Dictionary<string, object> Dict(string num, string customer, string item,
        decimal weight, decimal workmanship, decimal profit, decimal total)
        => new()
        {
            ["InvoiceNumber"] = num,
            ["InvoiceDate"] = "1405/06/0" + num[^1],
            ["CustomerName"] = customer,
            ["ItemCode"] = "G18",
            ["ItemTitle"] = item,
            ["WeightGram"] = weight,
            ["Workmanship"] = workmanship,
            ["Profit"] = profit,
            ["Tax"] = 12000m,
            ["TotalAmount"] = total
        };
}
