using Android.App;
using Android.Runtime;
using Microsoft.Maui;

namespace Tarazin.Maui;

[Application]
public class MainApplication : MauiApplication
{
    public MainApplication(IntPtr handle, JniHandleOwnership ownership)
        : base(handle, ownership)
    {
    }

    protected override MauiApp CreateMauiApp()
    {
        try
        {
            return MauiProgram.CreateMauiApp();
        }
        catch (Exception ex)
        {
            StartupCrashLog.Write("Android CreateMauiApp failed", ex);
            throw;
        }
    }
}
