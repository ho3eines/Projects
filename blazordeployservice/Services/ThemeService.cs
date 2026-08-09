using Microsoft.JSInterop;

namespace BlazorDeployService.Services
{
    public interface IThemeService
    {
        string CurrentTheme { get; }
        bool IsDarkMode { get; }

        event Action<bool> OnDarkModeChanged;
        event Action<string> OnThemeChanged;

        Task ApplyTheme();
        IEnumerable<string> GetAvailableThemes();
        string GetThemeName(string themeKey);
        Task InitializeAsync();
        Task SetThemeAsync(string themeKey);
        Task ToggleDarkAsync();
    }

    public class ThemeService : IThemeService
    {
        private readonly IJSRuntime _js;
        private const string KeyDark = "pref_isDark";
        private const string KeyTheme = "pref_theme";
        private IJSObjectReference? _jsModule;
        private bool _isInitialized = false;

        public bool IsDarkMode { get; private set; } = true;
        public string CurrentTheme { get; private set; } = "indigo";

        // Event برای اطلاع‌رسانی تغییر تم
        public event Action<string> OnThemeChanged;
        public event Action<bool> OnDarkModeChanged;

        private async Task LoadJS()
        {
            if (!_isInitialized)
            {
                _jsModule = await _js.InvokeAsync<IJSObjectReference>("import", "./_content/BlazorDeployService/js/interop.js?v1.0.1");
                _isInitialized = true;
            }
        }

        // لیست تم‌های Bootstrap
        private static readonly Dictionary<string, (string Name, string CssClass)> Themes =
            new()
            {
                ["indigo"] = ("Indigo", "theme-indigo"),
                ["emerald"] = ("Emerald", "theme-emerald"),
                ["blue"] = ("Blue", "theme-blue"),
                ["teal"] = ("Teal", "theme-teal"),
                ["rose"] = ("Rose", "theme-rose")
            };

        public ThemeService(IJSRuntime js)
        {
            _js = js;
        }

        public async Task InitializeAsync()
        {

            var dark = await _js.InvokeAsync<string?>("localStorage.getItem", KeyDark);
            var themeKey = await _js.InvokeAsync<string?>("localStorage.getItem", KeyTheme) ?? "indigo";

            IsDarkMode = dark != null ? dark == "1" : true;
            CurrentTheme = Themes.ContainsKey(themeKey) ? themeKey : "indigo";

            await ApplyTheme();
        }

        public async Task ToggleDarkAsync()
        {
            IsDarkMode = !IsDarkMode;
            await _js.InvokeVoidAsync("localStorage.setItem", KeyDark, IsDarkMode ? "1" : "0");
            await ApplyTheme();

            // اطلاع‌رسانی به همه کامپوننت‌ها
            OnDarkModeChanged?.Invoke(IsDarkMode);
        }

        public async Task SetThemeAsync(string themeKey)
        {
            if (!Themes.ContainsKey(themeKey))
                themeKey = "indigo";

            CurrentTheme = themeKey;
            await _js.InvokeVoidAsync("localStorage.setItem", KeyTheme, themeKey);
            await ApplyTheme();

            // اطلاع‌رسانی به همه کامپوننت‌ها
            OnThemeChanged?.Invoke(themeKey);
        }

        public async Task ApplyTheme()
        {
            await LoadJS();
            // حذف کلاس‌های قبلی
            await RemoveThemeClasses();

            // اعمال تم تاریک/روشن
            var themeMode = IsDarkMode ? "dark" : "light";
            Console.WriteLine(themeMode);
            await _jsModule.InvokeVoidAsync("changeTheme", themeMode);
            //await _js.InvokeVoidAsync("eval",
            //    $"document.documentElement.setAttribute('data-bs-theme', '{themeMode}');");

            // اعمال کلاس تم انتخابی
            var themeClass = Themes[CurrentTheme].CssClass;
            await _js.InvokeVoidAsync("eval",
                $"document.body.classList.add('{themeClass}');");

            // اعمال متغیرهای CSS
            await ApplyCssVariables();
        }

        private async Task RemoveThemeClasses()
        {
            var allThemeClasses = string.Join("', '", Themes.Values.Select(t => t.CssClass));
            await _js.InvokeVoidAsync("eval",
                $"document.body.classList.remove('{allThemeClasses}');");
        }

        private async Task ApplyCssVariables()
        {
            var cssVariables = GetCssVariablesForTheme(CurrentTheme);
            await _js.InvokeVoidAsync("eval", cssVariables);
        }

        private string GetCssVariablesForTheme(string themeKey)
        {
            return themeKey switch
            {
                "indigo" => @"
                    document.documentElement.style.setProperty('--bs-primary', '#3949ab');
                    document.documentElement.style.setProperty('--bs-secondary', '#5c6bc0');
                    document.documentElement.style.setProperty('--bs-success', '#43a047');
                    document.documentElement.style.setProperty('--bs-warning', '#fdd835');
                    document.documentElement.style.setProperty('--bs-danger', '#e53935');
                ",
                "emerald" => @"
                    document.documentElement.style.setProperty('--bs-primary', '#2e7d32');
                    document.documentElement.style.setProperty('--bs-secondary', '#66bb6a');
                    document.documentElement.style.setProperty('--bs-success', '#388e3c');
                    document.documentElement.style.setProperty('--bs-warning', '#fbc02d');
                    document.documentElement.style.setProperty('--bs-danger', '#d32f2f');
                ",
                "blue" => @"
                    document.documentElement.style.setProperty('--bs-primary', '#1565c0');
                    document.documentElement.style.setProperty('--bs-secondary', '#42a5f5');
                    document.documentElement.style.setProperty('--bs-success', '#0288d1');
                    document.documentElement.style.setProperty('--bs-warning', '#ffb300');
                    document.documentElement.style.setProperty('--bs-danger', '#e53935');
                ",
                "teal" => @"
                    document.documentElement.style.setProperty('--bs-primary', '#00796b');
                    document.documentElement.style.setProperty('--bs-secondary', '#26a69a');
                    document.documentElement.style.setProperty('--bs-success', '#00897b');
                    document.documentElement.style.setProperty('--bs-warning', '#ffd54f');
                    document.documentElement.style.setProperty('--bs-danger', '#e57373');
                ",
                "rose" => @"
                    document.documentElement.style.setProperty('--bs-primary', '#e91e63');
                    document.documentElement.style.setProperty('--bs-secondary', '#f06292');
                    document.documentElement.style.setProperty('--bs-success', '#ec407a');
                    document.documentElement.style.setProperty('--bs-warning', '#ffca28');
                    document.documentElement.style.setProperty('--bs-danger', '#ef5350');
                ",
                _ => @"
                    document.documentElement.style.setProperty('--bs-primary', '#3949ab');
                    document.documentElement.style.setProperty('--bs-secondary', '#5c6bc0');
                    document.documentElement.style.setProperty('--bs-success', '#43a047');
                    document.documentElement.style.setProperty('--bs-warning', '#fdd835');
                    document.documentElement.style.setProperty('--bs-danger', '#e53935');
                "
            };
        }

        public IEnumerable<string> GetAvailableThemes() => Themes.Keys;

        public string GetThemeName(string themeKey)
        {
            return Themes.ContainsKey(themeKey) ? Themes[themeKey].Name : "Indigo";
        }
    }
}