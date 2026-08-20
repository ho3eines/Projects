using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;

namespace Tarazin.Maui.WinUI;

/// <summary>
/// WinUI application head — this is the Windows entry point (equivalent of Main).
/// Unhandled exceptions here used to kill the process with no dialog.
/// </summary>
public partial class App : MauiWinUIApplication
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int MessageBoxW(nint hWnd, string lpText, string lpCaption, uint uType);

    public App()
    {
        UnhandledException += OnUnhandledException;
        this.InitializeComponent();
    }

    protected override MauiApp CreateMauiApp()
    {
        try
        {
            return MauiProgram.CreateMauiApp();
        }
        catch (Exception ex)
        {
            ShowFatal("راه‌اندازی برنامه شکست خورد.", ex);
            throw;
        }
    }

    private static void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        ShowFatal("یک خطای پیش‌بینی‌نشده رخ داد.", e.Exception);
        // Keep the process alive long enough for the dialog; otherwise WinUI
        // exits instantly and it looks like "the app never started".
        e.Handled = true;
    }

    private static void ShowFatal(string title, Exception ex)
    {
        Tarazin.Maui.StartupCrashLog.Write(title, ex);
        try
        {
            var text = title + Environment.NewLine + Environment.NewLine + Truncate(ex.ToString(), 1600)
                       + Environment.NewLine + Environment.NewLine
                       + "جزئیات: %LocalAppData%\\Tarazin\\maui-crash.log";
            MessageBoxW(0, text, "ترازین", 0x00000010);
        }
        catch
        {
            // ignored — log file is the fallback
        }
    }

    private static string Truncate(string value, int max)
        => value.Length <= max ? value : value[..max] + "…";
}
