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
