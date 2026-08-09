
    using Microsoft.JSInterop;
    using System;
    using System.Threading.Tasks;

namespace BlazorDeployService.Services
{
    public interface IStorageMonitorService
    {
        event Action<string> OnStorageCleared;

        ValueTask DisposeAsync();
        Task<string> GetClientIdAsync();
        Task InitializeAsync();
        void NotifyStorageCleared(string reason);
    }

    /// <summary>
    /// سرویس ساده برای مانیتورینگ storage
    /// </summary>
    public class StorageMonitorService : IAsyncDisposable, IStorageMonitorService
    {
        private readonly IJSRuntime _jsRuntime;
        private IJSObjectReference _module;
        private bool _isInitialized = false;

        public event Action<string> OnStorageCleared;

        public StorageMonitorService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        /// <summary>
        /// مقداردهی اولیه
        /// </summary>
        public async Task InitializeAsync()
        {
            if (_isInitialized) return;

            try
            {
                _module = await _jsRuntime.InvokeAsync<IJSObjectReference>(
                    "import", "./js/storageMonitor.js");

                var dotNetRef = DotNetObjectReference.Create(this);
                await _module.InvokeVoidAsync("setupStorageMonitoring", dotNetRef);

                _isInitialized = true;
                Console.WriteLine("StorageMonitorService initialized");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize StorageMonitorService: {ex.Message}");
            }
        }

        /// <summary>
        /// دریافت شناسه کاربر
        /// </summary>
        public async Task<string> GetClientIdAsync()
        {
            if (_module == null)
                await InitializeAsync();

            return await _module.InvokeAsync<string>("getOrCreateClientId");
        }

        /// <summary>
        /// فراخوانی از JavaScript
        /// </summary>
        [JSInvokable]
        public void NotifyStorageCleared(string reason)
        {
            OnStorageCleared?.Invoke(reason);
        }

        public async ValueTask DisposeAsync()
        {
            if (_module != null)
            {
                try
                {
                    await _module.InvokeVoidAsync("stopMonitoring");
                    await _module.DisposeAsync();
                }
                catch
                {
                    // ignore
                }
            }
        }
    }
}

