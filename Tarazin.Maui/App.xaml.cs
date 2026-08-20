namespace Tarazin.Maui;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        StartupCrashLog.Write("CreateWindow started");

        try
        {
            // اگر فایل‌های wwwroot کنار برنامه نباشند، BlazorWebView هیچ پاسخی
            // برنمی‌گرداند و کاربر فقط صفحهٔ خطای Edge را می‌بیند
            // («can't reach this page» روی 0.0.0.0 / ERR_CONNECTION_CLOSED)،
            // که هیچ سرنخی از علت واقعی نمی‌دهد. این بررسی همان علت را
            // به‌صورت صریح نشان می‌دهد به‌جای یک WebView خالی.
            var assets = HostAssetDiagnostics.InspectAndLog();
            if (!assets.IsHealthy && assets.UserMessage is not null)
            {
                StartupCrashLog.Write("CreateWindow aborted: web assets missing");
                return new Window(new StartupErrorPage("فایل‌های رابط کاربری یافت نشد.", assets.UserMessage))
                {
                    Title = "ترازین — خطای راه‌اندازی"
                };
            }

            var window = new Window(new MainPage())
            {
                Title = "ترازین"
            };

            StartupCrashLog.Write("CreateWindow completed");
            return window;
        }
        catch (Exception ex)
        {
            StartupCrashLog.Write("CreateWindow failed", ex);

            // Do not let Windows close the process silently. A native fallback
            // page does not depend on BlazorWebView/XAML resources and makes
            // the root cause visible to the operator.
            return new Window(new StartupErrorPage("راه‌اندازی رابط کاربری شکست خورد.", ex))
            {
                Title = "ترازین — خطای راه‌اندازی"
            };
        }
    }
}
