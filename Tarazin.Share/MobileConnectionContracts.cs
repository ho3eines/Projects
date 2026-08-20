namespace Tarazin.Models;

/// <summary>
/// One-time MAUI connection bootstrap request: just username and password over
/// HTTPS. The server verifies them exactly like the web login (PBKDF2 against
/// [central].[Users]) before handing out anything. The password's own SHA-256
/// is also the key input under which the connection string is encrypted, so
/// the client that typed a wrong password cannot decrypt the answer anyway.
/// </summary>
public sealed class ConnectionBootstrapRequest
{
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
}

/// <summary>
/// Successful bootstrap payload: the server's SQL connection string, encrypted
/// with AES-256-CBC under a key derived from the login password (SHA-256).
/// MAUI derives the same key from the password the user just typed and
/// decrypts it in memory — no key is stored in the app package. After this
/// single call, MAUI runs fully in-process exactly like the web host (local
/// PBKDF2 login + DbService); no server session exists.
/// </summary>
public sealed class ConnectionBootstrapResponse
{
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
