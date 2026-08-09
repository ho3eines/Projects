

namespace BlazorDeployService.Services
{
    public interface IClientStorageService
    {
        // LocalStorage
        Task SetLocalAsync<T>(string key, T value);
        Task<T?> GetLocalAsync<T>(string key);
        Task RemoveLocalAsync(string key);
        Task ClearLocalAsync();


        // LocalStorage (Encrypted)
        Task SetLocalEncryptedAsync<T>(string key, T value, string secretKey);
        Task<T?> GetLocalEncryptedAsync<T>(string key, string secretKey);


        // SessionStorage
        Task SetSessionAsync<T>(string key, T value);
        Task<T?> GetSessionAsync<T>(string key);
        Task RemoveSessionAsync(string key);
        Task ClearSessionAsync();


        // Cookies
        Task SetCookieAsync(string key, string value, int days = 30);
        Task<string?> GetCookieAsync(string key);
        Task RemoveCookieAsync(string key);


        // Cookies Secure + HttpOnly-like
        Task SetSecureCookieAsync(string key, string value, int days = 30);


        // Utilities
        string EncryptString(string plainText, string key);
        string DecryptString(string cipherText, string key);
    }
}