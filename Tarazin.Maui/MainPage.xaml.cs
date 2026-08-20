namespace Tarazin.Maui;

public partial class MainPage : ContentPage
{
    public MainPage()
    {
        StartupCrashLog.Write("MainPage InitializeComponent started");
        InitializeComponent();
        StartupCrashLog.Write("MainPage InitializeComponent completed");
    }
}
