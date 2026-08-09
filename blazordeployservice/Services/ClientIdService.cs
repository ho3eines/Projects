using Microsoft.JSInterop;
using System;
using System.Threading.Tasks;
using System.Timers;


namespace BlazorDeployService.Services
{
    public class ClientIdService : IClientIdService, IAsyncDisposable
    {
        private readonly IJSRuntime _jsRuntime;
        private IJSObjectReference? _jsModule;
        private DotNetObjectReference<ClientIdService> _dotNetRef;
        private string _clientId;
        private bool _wasCleared = false;
        private string _clearReason;
        private System.Timers.Timer _cleanupTimer;
        private bool _isInitialized = false;

        // رویداد پاک شدن storage
        public event EventHandler<StorageClearedEventArgs> StorageCleared;

        public bool WasStorageCleared => _wasCleared;
        public string StorageClearReason => _clearReason;

        public ClientIdService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        /// <summary>
        /// مقداردهی اولیه
        /// </summary>
        public async Task InitializeAsync()
        {
            if (!_isInitialized)
            {
                // بارگذاری ماژول JavaScript
                _jsModule = await _jsRuntime.InvokeAsync<IJSObjectReference>(
                "import", "./_content/BlazorDeployService/js/storageMonitor.js");
                _isInitialized = true;

            }

            // ایجاد reference برای فراخوانی از JavaScript
            _dotNetRef = DotNetObjectReference.Create(this);

            // راه‌اندازی مانیتورینگ
            await _jsModule.InvokeVoidAsync("setupStorageMonitoring", _dotNetRef);

            // دریافت یا ایجاد شناسه
            _clientId = await _jsModule.InvokeAsync<string>("getOrCreateClientId");

            // چک آیا storage قبلاً پاک شده بود؟
            await CheckPreviousStorageClear();

            // تایمر برای پاکسازی
            SetupCleanupTimer();

            Console.WriteLine($"ClientIdService initialized. ClientId: {_clientId}");
        }

        /// <summary>
        /// دریافت شناسه کاربر
        /// </summary>
        public async Task<string> GetClientIdAsync()
        {
            await InitializeAsync();

            if (string.IsNullOrEmpty(_clientId))
            {
                _clientId = await _jsModule.InvokeAsync<string>("getOrCreateClientId");
            }

            return _clientId;
        }

        /// <summary>
        /// فراخوانی از JavaScript هنگام پاک شدن storage
        /// </summary>
        [JSInvokable]
        public async Task OnStorageCleared(string reason)
        {
            _wasCleared = true;
            _clearReason = reason;

            // ذخیره برای لاگ
            await SaveStorageClearEvent(reason);

            // بازیابی شناسه از بکاپ
            await TryRecoverFromBackup();

            // اطلاع به دیگران
            StorageCleared?.Invoke(this, new StorageClearedEventArgs
            {
                Reason = reason,
                ClearedAt = DateTime.UtcNow,
                PreviousClientId = _clientId
            });

            // بروزرسانی شناسه
            _clientId = await GetClientIdAsync();

            Console.WriteLine($"Storage cleared detected! Reason: {reason}");
        }

        /// <summary>
        /// بررسی آیا storage در session قبلی پاک شده بود؟
        /// </summary>
        private async Task CheckPreviousStorageClear()
        {
            try
            {
                var wasCleared = await _jsRuntime.InvokeAsync<string>(
                    "sessionStorage.getItem", "storage_was_cleared");

                if (wasCleared == "true")
                {
                    _wasCleared = true;
                    _clearReason = "previous_session";

                    await _jsRuntime.InvokeVoidAsync(
                        "sessionStorage.removeItem", "storage_was_cleared");
                }
            }
            catch
            {
                // خطا در دسترسی به sessionStorage
            }
        }

        /// <summary>
        /// تلاش برای بازیابی از بکاپ
        /// </summary>
        private async Task TryRecoverFromBackup()
        {
            try
            {
                // 1. از sessionStorage بازیابی کن
                var backupId = await _jsRuntime.InvokeAsync<string>(
                    "sessionStorage.getItem", "clientId_backup");

                if (!string.IsNullOrEmpty(backupId))
                {
                    await _jsRuntime.InvokeVoidAsync(
                        "localStorage.setItem", "clientId", backupId);
                    return;
                }

                // 2. از cookie بازیابی کن
                backupId = await _jsModule.InvokeAsync<string>("getCookie", "clientId_backup");

                if (!string.IsNullOrEmpty(backupId))
                {
                    await _jsRuntime.InvokeVoidAsync(
                        "localStorage.setItem", "clientId", backupId);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to recover from backup: {ex.Message}");
            }
        }

        /// <summary>
        /// ذخیره رویداد پاک شدن
        /// </summary>
        private async Task SaveStorageClearEvent(string reason)
        {
            try
            {
                await _jsRuntime.InvokeVoidAsync("localStorage.setItem",
                    "last_storage_clear",
                    $"{DateTime.UtcNow:o}|{reason}"
                );
            }
            catch
            {
                // اگر storage پر است، لاگ کن
            }
        }

        /// <summary>
        /// راه‌اندازی تایمر پاکسازی
        /// </summary>
        private void SetupCleanupTimer()
        {
            _cleanupTimer = new System.Timers.Timer(300000); // هر 5 دقیقه
            _cleanupTimer.Elapsed += async (s, e) => await CleanupOldData();
            _cleanupTimer.AutoReset = true;
            _cleanupTimer.Start();
        }

        /// <summary>
        /// پاکسازی داده‌های قدیمی
        /// </summary>
        private async Task CleanupOldData()
        {
            try
            {
                // پاکسازی sessionStorage قدیمی
                await _jsRuntime.InvokeVoidAsync("eval", @"
                    const keys = Object.keys(sessionStorage);
                keys.forEach(key =>
                {
                    if (key.startsWith('temp_'))
                    {
                        sessionStorage.removeItem(key);
                    }
                });
                ");
            }
            catch
            {
                // خطا در پاکسازی
            }
        }

        /// <summary>
        /// پاکسازی منابع
        /// </summary>
        public async ValueTask DisposeAsync()
        {
            if (_cleanupTimer != null)
            {
                _cleanupTimer.Stop();
                _cleanupTimer.Dispose();
            }

            if (_jsModule != null)
            {
                await _jsModule.InvokeVoidAsync("stopMonitoring");
                await _jsModule.DisposeAsync();
            }

            _dotNetRef?.Dispose();

            Console.WriteLine("ClientIdService disposed");
        }
    }

}
