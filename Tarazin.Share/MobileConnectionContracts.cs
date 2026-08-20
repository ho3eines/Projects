namespace Tarazin.Models;

/// <summary>
/// MAUI login request: just username and password over HTTPS.
/// The password lives only in request memory and is also the (SHA-256-derived)
/// key input for decrypting the delivered connection string.
/// </summary>
public sealed class MobileLoginRequest
{
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
}

/// <summary>
/// Successful login payload: the signed-in user plus the server connection
/// string, encrypted with AES-256-CBC under a key derived from the login
/// password (SHA-256). MAUI derives the same key from the password the user
/// just typed and decrypts it in memory — no key is stored in the app package.
/// </summary>
public sealed class MobileLoginResponse
{
    public UserRow User { get; set; } = new();
    /// <summary>Encrypted connection string: ENC:Base64(IV + AES-CBC ciphertext).</summary>
    public string EncryptedConnectionString { get; set; } = "";
    /// <summary>Hint for diagnostics only: database name, never the full secret.</summary>
    public string Database { get; set; } = "";
}

/// <summary>Safe API error body; never contains exception, SQL, credential, or connection details.</summary>
public sealed class MobileConnectionError
{
    public string Code { get; set; } = "request_rejected";
    public string Message { get; set; } = "درخواست اتصال پذیرفته نشد.";
}
