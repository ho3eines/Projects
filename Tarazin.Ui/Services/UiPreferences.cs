namespace Tarazin.Services;

/// <summary>Per-circuit UI chrome (dark mode). Scoped like <see cref="UserSession"/>.</summary>
public sealed class UiPreferences
{
    public bool IsDarkMode { get; private set; }

    public event Action? Changed;

    public void SetDarkMode(bool value)
    {
        if (IsDarkMode == value) return;
        IsDarkMode = value;
        Changed?.Invoke();
    }

    public void ToggleDarkMode() => SetDarkMode(!IsDarkMode);
}
