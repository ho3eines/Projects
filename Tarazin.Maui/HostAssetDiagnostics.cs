using System.Text;

namespace Tarazin.Maui;

/// <summary>
/// بررسی «آیا فایل‌های وب (wwwroot) اصلاً کنار برنامه هستند؟».
///
/// چرا این کلاس وجود دارد — سناریوی واقعی Release ویندوز:
/// <c>BlazorWebView</c> صفحهٔ میزبان را از روی دیسک سرو می‌کند
/// (<c>WinUIWebViewManager.TryServeFromFolderAsync</c>):
///   • برنامهٔ packaged (MSIX نصب‌شده) → <c>Package.Current.InstalledLocation\wwwroot\index.html</c>
///   • برنامهٔ unpackaged            → <c>AppContext.BaseDirectory\wwwroot\index.html</c>
/// اگر فایل پیدا نشود، MAUI هیچ پاسخی برای درخواست ست نمی‌کند و WebView2 درخواست را
/// واقعاً به شبکه می‌فرستد؛ چون میزبان مجازی <c>0.0.0.0</c> است، Edge پیام
/// «Hmmm… can't reach this page / ERR_CONNECTION_CLOSED» را نشان می‌دهد.
/// یعنی آن خطای شبکه در عمل معنی‌اش «فایل نیست»، نه «اینترنت نیست».
///
/// در Debug این اتفاق نمی‌افتد چون Visual Studio بستهٔ packaged را درست register
/// می‌کند؛ در Release معمولاً exe لختِ داخل <c>bin\Release\...\</c> اجرا می‌شود در
/// حالی که محتوای بستهٔ packaged در <c>obj\...\MsixContent\</c> است، یا بستهٔ
/// نصب‌شده static web assets را ندارد.
///
/// خروجی این بررسی در <c>%LocalAppData%\Tarazin\maui-crash.log</c> نوشته می‌شود تا
/// به‌جای حدس زدن، دقیقاً معلوم باشد کدام حالت رخ داده است.
/// </summary>
internal static class HostAssetDiagnostics
{
    private const string ContentRoot = "wwwroot";
    private const string HostPage = "index.html";

    /// <summary>
    /// دارایی‌هایی که اگر نباشند، UI بالا نمی‌آید. مسیرها نسبت به ریشهٔ محتوا هستند.
    /// (<c>_framework/blazor.webview.js</c> عمداً بررسی نمی‌شود: آن فایل روی دیسک
    /// نیست و از منابع تعبیه‌شدهٔ خود فریم‌ورک سرو می‌شود.)
    /// </summary>
    private static readonly string[] RequiredAssets =
    {
        HostPage,
        Path.Combine("_content", "MudBlazor", "MudBlazor.min.css"),
        Path.Combine("_content", "Tarazin.Ui", "css", "app.css"),
    };

    /// <summary>وضعیت دارایی‌های وب؛ اگر چیزی کم باشد پیام فارسی قابل نمایش دارد.</summary>
    internal sealed record Result(bool IsHealthy, string Summary, string? UserMessage);

    internal static Result Inspect()
    {
        var report = new StringBuilder();
        var packaged = TryGetPackagedContentRoot(out var packagedRoot, out var packageError);

        report.AppendLine("بررسی دارایی‌های وب (wwwroot):");
        report.AppendLine($"  AppContext.BaseDirectory = {AppContext.BaseDirectory}");
        report.AppendLine($"  packaged (MSIX) = {packaged}");

        if (packageError is not null)
            report.AppendLine($"  packaged detection note = {packageError}");

        if (packaged && packagedRoot is not null)
            report.AppendLine($"  Package.InstalledLocation = {packagedRoot}");

        // این همان ترتیبی است که خود MAUI برای پیدا کردن فایل استفاده می‌کند.
        var searchRoot = packaged && packagedRoot is not null ? packagedRoot : AppContext.BaseDirectory;
        var contentRoot = Path.Combine(searchRoot, ContentRoot);

        report.AppendLine($"  مسیر مورد انتظار محتوا = {contentRoot}");
        report.AppendLine($"  وجود پوشهٔ محتوا = {Directory.Exists(contentRoot)}");

        var missing = new List<string>();
        foreach (var asset in RequiredAssets)
        {
            var full = Path.Combine(contentRoot, asset);
            var exists = File.Exists(full);
            report.AppendLine($"  {(exists ? "✓" : "✗")} {ContentRoot}\\{asset}");
            if (!exists)
                missing.Add(asset);
        }

        // اگر محتوا سر جایش نیست، جای واقعی‌اش را پیدا کن — همین یک خط معمولاً
        // کل معما را حل می‌کند (مثلاً «محتوا در MsixContent است، exe لخت اجرا شده»).
        if (missing.Count > 0)
        {
            foreach (var candidate in ProbeAlternativeLocations())
                report.AppendLine($"  محتوای پیداشده در مسیر دیگر: {candidate}");
        }

        var summary = report.ToString().TrimEnd();

        if (missing.Count == 0)
            return new Result(true, summary, null);

        var message = new StringBuilder();
        message.AppendLine("فایل‌های رابط کاربری (wwwroot) کنار برنامه نیستند، بنابراین صفحه بارگذاری نمی‌شود.");
        message.AppendLine();
        message.AppendLine("فایل‌های غایب:");
        foreach (var asset in missing)
            message.AppendLine($"  • {ContentRoot}\\{asset}");
        message.AppendLine();
        message.AppendLine($"مسیر جست‌وجو: {contentRoot}");
        message.AppendLine();
        message.AppendLine("این همان چیزی است که در مرورگر داخلی به‌صورت");
        message.AppendLine("«can't reach this page / ERR_CONNECTION_CLOSED» روی 0.0.0.0 دیده می‌شود:");
        message.AppendLine("چون فایل پیدا نمی‌شود، درخواست به شبکه می‌رود و شکست می‌خورد.");
        message.AppendLine();
        message.AppendLine("راهنمای رفع: docs/WINDOWS_MAUI_LAUNCH.md");

        return new Result(false, summary, message.ToString().TrimEnd());
    }

    /// <summary>نتیجهٔ بررسی را در لاگ startup می‌نویسد و همان را برمی‌گرداند.</summary>
    internal static Result InspectAndLog()
    {
        Result result;
        try
        {
            result = Inspect();
        }
        catch (Exception ex)
        {
            StartupCrashLog.Write("بررسی دارایی‌های وب شکست خورد", ex);
            return new Result(true, "بررسی انجام نشد", null); // مانع اجرا نشو
        }

        StartupCrashLog.Write(result.Summary);
        if (!result.IsHealthy && result.UserMessage is not null)
            StartupCrashLog.Write("دارایی‌های وب ناقص‌اند:" + Environment.NewLine + result.UserMessage);

        return result;
    }

    /// <summary>
    /// مسیرهای رایجی که محتوای وب «اشتباهی» آنجا می‌ماند (خروجی packaged در برابر
    /// اجرای مستقیم exe). فقط برای راهنمایی در لاگ.
    /// </summary>
    private static IEnumerable<string> ProbeAlternativeLocations()
    {
        var baseDir = AppContext.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(baseDir, "MsixContent", ContentRoot, HostPage),
            Path.Combine(baseDir, "..", "MsixContent", ContentRoot, HostPage),
            Path.Combine(baseDir, "..", ContentRoot, HostPage),
        };

        foreach (var candidate in candidates)
        {
            string full;
            try
            {
                full = Path.GetFullPath(candidate);
            }
            catch
            {
                continue;
            }

            if (File.Exists(full))
                yield return full;
        }
    }

    /// <summary>
    /// ریشهٔ نصب بستهٔ MSIX را برمی‌گرداند. در برنامهٔ unpackaged، دسترسی به
    /// <c>Package.Current</c> استثنا می‌دهد — دقیقاً همان‌طور که خود MAUI هم
    /// packaged بودن را تشخیص می‌دهد.
    /// </summary>
    private static bool TryGetPackagedContentRoot(out string? installedLocation, out string? note)
    {
        installedLocation = null;
        note = null;

#if WINDOWS
        try
        {
            var package = Windows.ApplicationModel.Package.Current;
            if (package is null)
                return false;

            installedLocation = package.InstalledLocation.Path;
            return true;
        }
        catch (Exception ex)
        {
            note = "unpackaged (" + ex.GetType().Name + ")";
            return false;
        }
#else
        note = "بررسی packaged فقط روی ویندوز معنا دارد";
        return false;
#endif
    }
}
