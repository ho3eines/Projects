using System.Security.Cryptography;
using System.Text;

namespace Tarazin.Data;

/// <summary>
/// Encrypts / decrypts connection strings for secure storage in appsettings.json
/// and for encrypted delivery to MAUI clients. Uses AES-256-CBC with a random
/// IV prepended to the ciphertext. The persisted / transported value is
/// <c>ENC:{Base64(IV + Ciphertext)}</c>.
/// </summary>
public static class ConnectionStringProtector
{
    public const string EncryptedPrefix = "ENC:";

    // -------------------------------------------------------------------
    // Static-key API (used for appsettings.json at rest)
    // -------------------------------------------------------------------

    public static bool IsEncrypted(string? value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Trim().StartsWith(EncryptedPrefix, StringComparison.Ordinal);

    /// <summary>Creates a fresh 256-bit key suitable for appsettings / env var.</summary>
    public static string GenerateKeyBase64()
        => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

    public static string Encrypt(string plaintext, string base64Key)
    {
        if (string.IsNullOrEmpty(plaintext))
            throw new ArgumentException("Plaintext must not be empty.", nameof(plaintext));
        var key = DecodeKey(base64Key);
        return EncryptWithKeyBytes(plaintext, key);
    }

    public static string Decrypt(string encryptedValue, string base64Key)
    {
        if (!IsEncrypted(encryptedValue))
            throw new ArgumentException("Value is not in ENC: format.", nameof(encryptedValue));
        var key = DecodeKey(base64Key);
        return DecryptWithKeyBytes(encryptedValue, key);
    }

    // -------------------------------------------------------------------
    // Raw-key API (used for per-session delivery where the key is derived
    // from the bearer token so no static secret is stored in the MAUI binary)
    // -------------------------------------------------------------------

    public static string EncryptWithKeyBytes(string plaintext, byte[] keyBytes)
    {
        ValidateKey(keyBytes);
        var iv = RandomNumberGenerator.GetBytes(16);
        var plainBytes = Encoding.UTF8.GetBytes(plaintext);

        using var aes = Aes.Create();
        aes.Key = keyBytes;
        aes.IV = iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;

        using var encryptor = aes.CreateEncryptor();
        var cipherBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);

        var combined = new byte[iv.Length + cipherBytes.Length];
        Buffer.BlockCopy(iv, 0, combined, 0, iv.Length);
        Buffer.BlockCopy(cipherBytes, 0, combined, iv.Length, cipherBytes.Length);

        return EncryptedPrefix + Convert.ToBase64String(combined);
    }

    public static string DecryptWithKeyBytes(string encryptedValue, byte[] keyBytes)
    {
        ValidateKey(keyBytes);
        if (!IsEncrypted(encryptedValue))
            throw new ArgumentException("Value is not in ENC: format.", nameof(encryptedValue));

        var raw = encryptedValue.Trim()[EncryptedPrefix.Length..].Trim();
        var combined = Convert.FromBase64String(raw);
        if (combined.Length <= 16)
            throw new CryptographicException("Encrypted payload is too short.");

        var iv = new byte[16];
        var cipher = new byte[combined.Length - 16];
        Buffer.BlockCopy(combined, 0, iv, 0, 16);
        Buffer.BlockCopy(combined, 16, cipher, 0, cipher.Length);

        using var aes = Aes.Create();
        aes.Key = keyBytes;
        aes.IV = iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;

        using var decryptor = aes.CreateDecryptor();
        var plainBytes = decryptor.TransformFinalBlock(cipher, 0, cipher.Length);
        return Encoding.UTF8.GetString(plainBytes);
    }

    /// <summary>
    /// Derives a 32-byte AES key from a bearer/session token (SHA-256 of the UTF-8 token).
    /// Both Web and MAUI can derive the same key without storing a long-term secret.
    /// </summary>
    public static byte[] DeriveKeyFromToken(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
            throw new ArgumentException("Token must not be empty.", nameof(token));
        return SHA256.HashData(Encoding.UTF8.GetBytes(token));
    }

    // -------------------------------------------------------------------
    // Key resolution helpers
    // -------------------------------------------------------------------

    /// <summary>
    /// Resolves the static encryption key for appsettings.json at rest.
    /// Priority: environment <c>TARAZIN_ENCRYPTION_KEY</c> → configuration
    /// <c>ConnectionProtection:Key</c> (or <c>ConnectionProtection__Key</c>).
    /// Returns <c>null</c> when nothing is configured.
    /// </summary>
    public static string? ResolveStaticKey(Microsoft.Extensions.Configuration.IConfiguration? configuration)
    {
        var fromEnv = Environment.GetEnvironmentVariable("TARAZIN_ENCRYPTION_KEY");
        if (!string.IsNullOrWhiteSpace(fromEnv))
            return fromEnv.Trim();

        // Support both colon and double-underscore notation for env-style overrides.
        var fromConfig = configuration?["ConnectionProtection:Key"]?.Trim();
        if (!string.IsNullOrWhiteSpace(fromConfig))
            return fromConfig;

        fromConfig = configuration?["ConnectionProtection__Key"]?.Trim();
        if (!string.IsNullOrWhiteSpace(fromConfig))
            return fromConfig;

        // Legacy / MAUI key location
        fromConfig = configuration?["EncryptionKey"]?.Trim();
        if (!string.IsNullOrWhiteSpace(fromConfig))
            return fromConfig;

        return null;
    }

    public static byte[] DecodeKey(string base64Key)
    {
        if (string.IsNullOrWhiteSpace(base64Key))
            throw new ArgumentException("Encryption key must not be empty.", nameof(base64Key));
        try
        {
            var key = Convert.FromBase64String(base64Key.Trim());
            ValidateKey(key);
            return key;
        }
        catch (FormatException ex)
        {
            throw new ArgumentException("Encryption key is not valid Base64.", nameof(base64Key), ex);
        }
    }

    private static void ValidateKey(byte[] key)
    {
        if (key.Length != 32)
            throw new ArgumentException($"AES-256 requires a 32-byte key (got {key.Length}). Supply a Base64-encoded 32-byte key via TARAZIN_ENCRYPTION_KEY or ConnectionProtection:Key.", nameof(key));
    }
}
