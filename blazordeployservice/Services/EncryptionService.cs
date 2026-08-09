using BlazorDeployService.Models;
using Microsoft.Extensions.Options;
using Microsoft.JSInterop;

namespace BlazorDeployService.Services
{
    public class EncryptionService : IEncryptionService, IAsyncDisposable
    {
        private readonly IJSRuntime _jsRuntime;
        private IJSObjectReference? _jsModule;
        private readonly AppSettings _appSettings;
        private bool _isInitialized = false;

        public EncryptionService(IJSRuntime jsRuntime, IOptions<AppSettings> appSettings)
        {
            _jsRuntime = jsRuntime;
            _appSettings = appSettings.Value;
        }

        public async Task InitializeAsync()
        {
            if (!_isInitialized)
            {
                if (_jsModule is null)
                    _jsModule = await _jsRuntime.InvokeAsync<IJSObjectReference>("import", "./_content/BlazorDeployService/js/interop.js");
                _isInitialized = true;
            }
        }

        public async Task<string> GenerateRandomKey()
        {
            await EnsureInitializedAsync();

            try
            {
                return await _jsModule!.InvokeAsync<string>("generateRandomKey");
            }
            catch (JSException ex)
            {
                throw new InvalidOperationException($"Encryption failed: {ex.Message}", ex);
            }
        }
        public async Task<string> EncryptDataAsync(string data, string key = "")
        {
            await EnsureInitializedAsync();

            if (string.IsNullOrEmpty(key))
                key = _appSettings.Encryption.Key;

            if (string.IsNullOrEmpty(data))
                throw new ArgumentException("Data cannot be null or empty");

            if (string.IsNullOrEmpty(key))
                throw new ArgumentException("Key cannot be null or empty");

            try
            {
                // فراخوانی تابع encryptData از فایل JS
                return await _jsModule!.InvokeAsync<string>("encryptData", data, key);
            }
            catch (JSException ex)
            {
                throw new InvalidOperationException($"Encryption failed: {ex.Message}", ex);
            }
        }

        public async Task<string> DecryptDataAsync(string encryptedData, string key = "")
        {
            await EnsureInitializedAsync();

            if (string.IsNullOrEmpty(key))
                key = _appSettings.Encryption.Key;

            if (string.IsNullOrEmpty(encryptedData))
                throw new ArgumentException("Encrypted data cannot be null or empty");

            if (string.IsNullOrEmpty(key))
                throw new ArgumentException("Key cannot be null or empty");

            try
            {
                // فراخوانی تابع decryptData از فایل JS
                return await _jsModule!.InvokeAsync<string>("decryptData", encryptedData, key);
            }
            catch (JSException ex)
            {
                throw new InvalidOperationException($"Decryption failed: {ex.Message}", ex);
            }
        }

        private async Task EnsureInitializedAsync()
        {
            if (!_isInitialized)
            {
                await InitializeAsync();
            }
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