using Microsoft.JSInterop;
using System.Threading.Tasks;

namespace BlazorDeployService.Services
{
    public interface IAlertService
    {
        Task ShowSuccessAsync(string title, string message, int duration = 5000);
        Task ShowWarningAsync(string title, string message, int duration = 5000);
        Task ShowErrorAsync(string title, string message, int duration = 5000);
        Task ShowInfoAsync(string title, string message, int duration = 5000);
        Task ShowCustomAsync(string type, string title, string message, int duration = 5000);
        Task HideAllAsync();
    }
    public class AlertService : IAlertService
    {
        private readonly IJSRuntime _js;
        private bool _isInitialized = false;
        private IJSObjectReference? _jsModule;

        public AlertService(IJSRuntime jsRuntime)
        {
            _js = jsRuntime;
        }

        private async Task EnsureInitializedAsync()
        {
            if (!_isInitialized)
            {
                // لود ماژول JavaScript
                _jsModule = await _js.InvokeAsync<IJSObjectReference>(
                    "import",
                    "./_content/BlazorDeployService/js/alertManager.js"
                );

                // مقداردهی اولیه
                await _jsModule.InvokeVoidAsync("initialize");
                _isInitialized = true;
            }
        }

        public async Task ShowSuccessAsync(string title, string message, int duration = 5000)
        {
            await EnsureInitializedAsync();
            await _jsModule.InvokeVoidAsync("showAlert", "success", title, message, duration);
        }

        public async Task ShowWarningAsync(string title, string message, int duration = 5000)
        {
            await EnsureInitializedAsync();
            await _jsModule.InvokeVoidAsync("showAlert", "warning", title, message, duration);
        }

        public async Task ShowErrorAsync(string title, string message, int duration = 5000)
        {
            await EnsureInitializedAsync();
            await _jsModule.InvokeVoidAsync("showAlert", "error", title, message, duration);
        }

        public async Task ShowInfoAsync(string title, string message, int duration = 5000)
        {
            await EnsureInitializedAsync();
            await _jsModule.InvokeVoidAsync("showAlert", "info", title, message, duration);
        }

        public async Task ShowCustomAsync(string type, string title, string message, int duration = 5000)
        {
            await EnsureInitializedAsync();
            await _jsModule.InvokeVoidAsync("showAlert", type, title, message, duration);
        }

        public async Task HideAllAsync()
        {
            await EnsureInitializedAsync();
            await _jsModule.InvokeVoidAsync("hideAllAlerts");
        }

        public async ValueTask DisposeAsync()
        {
            if (_jsModule != null)
            {
                await _jsModule.DisposeAsync();
            }
        }
    }
}

