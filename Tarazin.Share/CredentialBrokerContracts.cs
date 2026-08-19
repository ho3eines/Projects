namespace Tarazin.Models;

/// <summary>One-time, replay-protected MAUI login request. Password exists only in request memory.</summary>
public sealed class MobileConnectionRequest
{
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
    public Guid CustomerGuid { get; set; }
    public string Nonce { get; set; } = "";
    public DateTimeOffset TimestampUtc { get; set; }
}

/// <summary>Bearer-session refresh request. The bearer token is sent in the Authorization header.</summary>
public sealed class MobileConnectionRefreshRequest
{
    public Guid CustomerGuid { get; set; }
    public string Nonce { get; set; } = "";
    public DateTimeOffset TimestampUtc { get; set; }
}

/// <summary>Short-lived SQL material returned only after all API validations pass.</summary>
public sealed class MobileSqlCredential
{
    public string Server { get; set; } = "";
    public string Database { get; set; } = "";
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
    public DateTimeOffset ExpiresAtUtc { get; set; }
    public bool Encrypt { get; set; } = true;
    public bool TrustServerCertificate { get; set; }
}

public sealed class MobileConnectionResponse
{
    public UserRow User { get; set; } = new();
    public Guid CustomerGuid { get; set; }
    public string SessionToken { get; set; } = "";
    public DateTimeOffset SessionExpiresAtUtc { get; set; }
    public MobileSqlCredential Credential { get; set; } = new();
}

/// <summary>Safe API error body; never contains exception, SQL, credential, or token details.</summary>
public sealed class CredentialBrokerError
{
    public string Code { get; set; } = "request_rejected";
    public string Message { get; set; } = "درخواست اتصال پذیرفته نشد.";
}

/// <summary>
/// Authenticated request for the encrypted master connection string.
/// The bearer token is sent in the Authorization header; body carries
/// replay protection and tenant binding.
/// </summary>
public sealed class EncryptedConnectionRequest
{
    public Guid CustomerGuid { get; set; }
    public string Nonce { get; set; } = "";
    public DateTimeOffset TimestampUtc { get; set; }
}

/// <summary>
/// Encrypted master connection string response. The string is
/// <c>ENC:Base64(IV+Ciphertext)</c> encrypted with a per-session key
/// derived from the bearer token (SHA-256 of the token), so no static
/// secret is stored in the MAUI binary. Transport is still over HTTPS.
/// </summary>
public sealed class EncryptedConnectionResponse
{
    /// <summary>Encrypted connection string: ENC:Base64(IV + AES-CBC ciphertext).</summary>
    public string EncryptedConnectionString { get; set; } = "";
    public DateTimeOffset ExpiresAtUtc { get; set; }
    /// <summary>Hint for diagnostics only: database name, never the full secret.</summary>
    public string Database { get; set; } = "";
}
