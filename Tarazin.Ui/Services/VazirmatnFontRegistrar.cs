using System.IO;

namespace Tarazin.Services;

/// <summary>
/// ثبت فونت Vazirmatn در موتور رندر PDF (QuestPDF) از همان بایت‌های TTFِ EmbeddedResource
/// (فایل‌های wwwroot/fonts/Vazirmatn-*.ttf که همراه اسمبلی Tarazin.Ui جاسازی شده‌اند).
///
/// چرا لازم است:
/// - QuestPDF (PDF سمت سرور/MAUI) برخلاف مرورگر به CDN/فونت سیستمی تکیه نمی‌کند؛
///   اگر فونت «Vazirmatn» ثبت نشود، خروجی PDF با فونت پیش‌فرض (لِتین) رندر می‌شود.
///   این کلاس همان ثبت را متمرکز می‌کند تا همهٔ چاپ‌ها از یک منبع استفاده کنند.
///
/// <c>Register()</c> از <see cref="ServiceCollectionExtensions.AddTarazinUiServices"/> صدا
/// زده می‌شود؛ چون هر دو هاست (Web و MAUI) از آن استفاده می‌کنند، ثبت در استارتاپ هر دو
/// انجام می‌شود. Idempotent است (ثبت تکراری خطا نمی‌دهد).
/// </summary>
public static class VazirmatnFontRegistrar
{
    public const string FamilyName = "Vazirmatn";

    private const string RegularResource = "Tarazin.Ui.fonts.Vazirmatn-Regular.ttf";
    private const string BoldResource = "Tarazin.Ui.fonts.Vazirmatn-Bold.ttf";

    private static int _registered;

    /// <summary>ثبت فونت Vazirmatn در QuestPDF — یک‌بار در فرایند.</summary>
    public static void Register()
    {
        // Thread-safe idempotent guard: ثبت تکراری (مثلاً چند بار ساخت DI) ضرری ندارد.
        if (System.Threading.Interlocked.Exchange(ref _registered, 1) == 1)
            return;

        try
        {
            var assembly = typeof(VazirmatnFontRegistrar).Assembly;

            RegisterQuestPdf(assembly, RegularResource);
            RegisterQuestPdf(assembly, BoldResource);
        }
        catch
        {
            // اگر فونت ثبت نشود، موتور به فونت پیش‌فرض برمی‌گردد؛
            // خطا نباید استارتاپ یا چاپ را بشکند.
        }
    }

    private static void RegisterQuestPdf(System.Reflection.Assembly assembly, string resource)
    {
        using var stream = assembly.GetManifestResourceStream(resource);
        if (stream is not null)
            QuestPDF.Drawing.FontManager.RegisterFont(stream);
    }
}
