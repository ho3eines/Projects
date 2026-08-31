using System;
using System.IO;
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
}
