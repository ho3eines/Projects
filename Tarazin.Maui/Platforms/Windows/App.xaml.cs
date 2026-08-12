using Microsoft.UI.Xaml;

namespace Tarazin.Maui.WinUI;

/// <summary>
/// WinUI application head — this is the Windows entry point (equivalent of Main).
/// </summary>
public partial class App : MauiWinUIApplication
{
    public App()
    {
        this.InitializeComponent();
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
