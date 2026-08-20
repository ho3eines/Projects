namespace Tarazin.Maui;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        try
        {
            return new Window(new MainPage());
        }
        catch (Exception ex)
        {
            StartupCrashLog.Write("CreateWindow failed", ex);
            throw;
        }
    }
}
