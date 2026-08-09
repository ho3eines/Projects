using Microsoft.JSInterop;

namespace BlazorDeployService.Services
{
    public interface IEncryptionService
    {
        Task<string> EncryptDataAsync(string data, string key="");
        Task<string> DecryptDataAsync(string encryptedData, string key="");
        Task<string> GenerateRandomKey();
        Task InitializeAsync();
    }
}