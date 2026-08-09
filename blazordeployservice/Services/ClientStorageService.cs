using Microsoft.JSInterop;
using System.Text.Json;
using System.Threading.Tasks;
using System;
using System.Security.Cryptography;
using System.Text;


namespace BlazorDeployService.Services
{
    public class ClientStorageService : IClientStorageService
    {
        private readonly IJSRuntime _js;

        public ClientStorageService(IJSRuntime js)
        {
            _js = js;
        }

        // ----------------------- LocalStorage -----------------------
        public async Task SetLocalAsync<T>(string key, T value)
        {
            await _js.InvokeVoidAsync("localStorage.setItem", key, JsonSerializer.Serialize(value));
        }

        public async Task<T?> GetLocalAsync<T>(string key)
        {
            var json = await _js.InvokeAsync<string>("localStorage.getItem", key);
            if (string.IsNullOrWhiteSpace(json)) return default;
            return JsonSerializer.Deserialize<T>(json);
        }


        public async Task RemoveLocalAsync(string key)
        {
            await _js.InvokeVoidAsync("localStorage.removeItem", key);
        }


        public async Task ClearLocalAsync()
        {
            await _js.InvokeVoidAsync("localStorage.clear");
        }


        // ----------------------- LocalStorage Encrypted -----------------------
        public async Task SetLocalEncryptedAsync<T>(string key, T value, string secretKey)
        {
            var json = JsonSerializer.Serialize(value);
            var encrypted = EncryptString(json, secretKey);
            await _js.InvokeVoidAsync("localStorage.setItem", key, encrypted);
        }


        public async Task<T?> GetLocalEncryptedAsync<T>(string key, string secretKey)
        {
            var encrypted = await _js.InvokeAsync<string>("localStorage.getItem", key);
            if (string.IsNullOrWhiteSpace(encrypted)) return default;


            var decrypted = DecryptString(encrypted, secretKey);
            return JsonSerializer.Deserialize<T>(decrypted);
        }


        // ----------------------- SessionStorage -----------------------
        public async Task SetSessionAsync<T>(string key, T value)
        {
            await _js.InvokeVoidAsync("sessionStorage.setItem", key, JsonSerializer.Serialize(value));
        }


        public async Task<T?> GetSessionAsync<T>(string key)
        {
            var json = await _js.InvokeAsync<string>("sessionStorage.getItem", key);
            if (string.IsNullOrWhiteSpace(json)) return default;
            return JsonSerializer.Deserialize<T>(json);
        }


        public async Task RemoveSessionAsync(string key)
        {
            await _js.InvokeVoidAsync("sessionStorage.removeItem", key);
        }


        public async Task ClearSessionAsync()
        {
            await _js.InvokeVoidAsync("sessionStorage.clear");
        }


        // ----------------------- Cookies -----------------------
        public async Task SetCookieAsync(string key, string value, int days = 30)
        {
            await _js.InvokeVoidAsync("eval", $"document.cookie = '{key}={value}; path=/; max-age={days * 86400}'");
        }


        public async Task<string?> GetCookieAsync(string key)
        {
            var cookies = await _js.InvokeAsync<string>("eval", "document.cookie");
            if (string.IsNullOrWhiteSpace(cookies)) return null;


            var parts = cookies.Split(';');
            foreach (var part in parts)
            {
                var cookie = part.Trim();
                if (cookie.StartsWith(key + "="))
                {
                    return cookie.Substring(key.Length + 1);
                }
            }
            return null;
        }


        public async Task RemoveCookieAsync(string key)
        {
            await _js.InvokeVoidAsync("eval", $"document.cookie = '{key}=; path=/; max-age=0'");
        }


        // ----------------------- Secure Cookies (HTTP-Only replacement) -----------------------
        public async Task SetSecureCookieAsync(string key, string value, int days = 30)
        {
            var encrypted = Convert.ToBase64String(Encoding.UTF8.GetBytes(value));
            await _js.InvokeVoidAsync("eval", $"document.cookie = '{key}={encrypted}; path=/; SameSite=Strict; Secure; max-age={days * 86400}'");
        }


        // ----------------------- AES Encryption Utilities -----------------------
        public string EncryptString(string plainText, string key)
        {
            using var aes = Aes.Create();
            var keyBytes = SHA256.HashData(Encoding.UTF8.GetBytes(key));
            aes.Key = keyBytes;
            aes.GenerateIV();


            var encryptor = aes.CreateEncryptor();
            var bytes = Encoding.UTF8.GetBytes(plainText);
            var encrypted = encryptor.TransformFinalBlock(bytes, 0, bytes.Length);


            var result = Convert.ToBase64String(aes.IV) + ":" + Convert.ToBase64String(encrypted);
            return result;
        }


        public string DecryptString(string cipherText, string key)
        {
            var parts = cipherText.Split(':');
            var iv = Convert.FromBase64String(parts[0]);
            var encrypted = Convert.FromBase64String(parts[1]);


            using var aes = Aes.Create();
            aes.Key = SHA256.HashData(Encoding.UTF8.GetBytes(key));
            aes.IV = iv;


            var decryptor = aes.CreateDecryptor();
            var decrypted = decryptor.TransformFinalBlock(encrypted, 0, encrypted.Length);
            return Encoding.UTF8.GetString(decrypted);
        }
    }
}
