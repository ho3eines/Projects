using Microsoft.Extensions.Localization;
using Microsoft.JSInterop;
using System.Globalization;

namespace BlazorDeployService.Services
{
    public interface ICultureService
    {
        CultureInfo CurrentCulture { get; }

        event Action? OnCultureChanged;

        Task ApplyDirectionAsync();
        Task<string> GetLang();
        Task InitializeAsync();
        bool isRtl();
        Task SetCulture(string cultureCode);
    }

    public class CultureService : ICultureService
    {

        private readonly IJSRuntime _js;
        private readonly IClientStorageService _clientstorage;
        private const string KeyCulture = "pref_culture";
        private string Lang;
        private IJSObjectReference? _jsModule;
        private bool _isInitialized = false;

        public CultureInfo CurrentCulture { get; private set; } = CultureInfo.CurrentCulture;

        public event Action? OnCultureChanged;

        public CultureService(IClientStorageService clientStorage, IJSRuntime js)
        {
            _clientstorage = clientStorage;
            _js = js;
        }

        private async Task LoadJS()
        {
            if (!_isInitialized)
            {
                _jsModule = await _js.InvokeAsync<IJSObjectReference>("import", "./_content/BlazorDeployService/js/interop.js?v1.0.1");
                _isInitialized = true;
            }
        }

        public async Task InitializeAsync()
        {

            //var code = await _js.InvokeAsync<string?>("localStorage.getItem", KeyCulture);
            var code = await _clientstorage.GetLocalAsync<string?>(KeyCulture);
            if (!string.IsNullOrWhiteSpace(code))
                await SetCulture(code);
            else
                await SetCulture("fa-IR");

        }

        public async Task ApplyDirectionAsync()
        {
            await InitializeAsync();

        }

        public async Task SetCulture(string cultureCode)
        {
            await LoadJS();

            Lang = cultureCode;
            var culture = new CultureInfo(cultureCode);
            CultureInfo.DefaultThreadCurrentCulture = culture;
            CultureInfo.DefaultThreadCurrentUICulture = culture;
            CurrentCulture = culture;
            //await _js.InvokeVoidAsync("localStorage.setItem", KeyCulture, cultureCode);
            await _clientstorage.SetLocalAsync(KeyCulture, cultureCode);

            await _jsModule.InvokeVoidAsync("changeLang", ChangeLang(cultureCode.ToString()));
            await _jsModule.InvokeVoidAsync("changeDir", ChangeDirection(cultureCode.ToString()));

            OnCultureChanged?.Invoke();
        }

        public async Task<string> GetLang()
        {
            await LoadJS();
            if (string.IsNullOrEmpty(Lang))
                Lang = await _clientstorage.GetLocalAsync<string?>(KeyCulture) ?? "fa-IR";
            await _jsModule.InvokeVoidAsync("changeLang", ChangeLang(Lang.ToString()));
            await _jsModule.InvokeVoidAsync("changeDir", ChangeDirection(Lang.ToString()));
            //Lang = await _js.InvokeAsync<string?>("localStorage.getItem", KeyCulture)?? "fa-IR";
            return Lang;
        }
        public bool isRtl() => CurrentCulture.TextInfo.IsRightToLeft;

        private string ChangeDirection(string? keyCulture)
        {
            if (string.IsNullOrEmpty(keyCulture))
                return "rtl";
            else if (keyCulture == "fa-IR" || keyCulture == "ar-SA")
                return "rtl";
            else return "ltr";
        }
        private string ChangeLang(string? keyCulture)
        {
            string lang;

            switch (keyCulture)
            {
                case "fa-IR":
                    lang = "fa";
                    break;
                case "en-US":
                    lang = "en";
                    break;
                case "ar-SA":
                    lang = "ar";
                    break;
                case "ru-RU":
                    lang = "ru";
                    break;
                case "de-DE":
                    lang = "de";
                    break;
                case "es-ES":
                    lang = "es";
                    break;
                case "zh-CN":
                    lang = "zh";
                    break;
                case "ja-JP":
                    lang = "ja";
                    break;
                default:
                    lang = "fa";
                    break;
            }

            return lang;
        }
    }
}
