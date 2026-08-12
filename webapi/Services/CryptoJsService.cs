using System.Security.Cryptography;
using System.Text;

namespace WebApi.Services;

/// <summary>AES-256-CBC compatible with BlazorDeployService wwwroot/js/interop.js</summary>
public sealed class CryptoJsService
{
    public string Encrypt(string key, string plainText)
    {
        ArgumentException.ThrowIfNullOrEmpty(key);
        ArgumentException.ThrowIfNullOrEmpty(plainText);

        var keyBytes = SHA256.HashData(Encoding.UTF8.GetBytes(key));
        var iv = RandomNumberGenerator.GetBytes(16);

        using var aes = Aes.Create();
        aes.Key = keyBytes;
        aes.IV = iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;

        using var encryptor = aes.CreateEncryptor();
        var plainBytes = Encoding.UTF8.GetBytes(plainText);
        var cipherBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);

        var result = new byte[iv.Length + cipherBytes.Length];
        Buffer.BlockCopy(iv, 0, result, 0, iv.Length);
        Buffer.BlockCopy(cipherBytes, 0, result, iv.Length, cipherBytes.Length);
        return Convert.ToBase64String(result);
    }

    public string Decrypt(string key, string encryptedText)
    {
        ArgumentException.ThrowIfNullOrEmpty(key);
        ArgumentException.ThrowIfNullOrEmpty(encryptedText);

        var full = Convert.FromBase64String(encryptedText);
        if (full.Length < 17)
            throw new CryptographicException("Ciphertext too short.");

        var iv = new byte[16];
        Buffer.BlockCopy(full, 0, iv, 0, 16);
        var cipher = new byte[full.Length - 16];
        Buffer.BlockCopy(full, 16, cipher, 0, cipher.Length);

        var keyBytes = SHA256.HashData(Encoding.UTF8.GetBytes(key));
        using var aes = Aes.Create();
        aes.Key = keyBytes;
        aes.IV = iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;

        using var decryptor = aes.CreateDecryptor();
        var plainBytes = decryptor.TransformFinalBlock(cipher, 0, cipher.Length);
        return Encoding.UTF8.GetString(plainBytes);
    }
}
