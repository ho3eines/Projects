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
/// Payload served by the web connection endpoint (<c>api/{guid}</c>) to MAUI.
/// Per the product decision the full, server-managed SQL connection string is
/// returned; it must never be written to logs, diagnostics, or MAUI storage.
/// </summary>
public sealed class ConnectionStringPayload
{
    public Guid Guid { get; set; }
    public string ConnectionString { get; set; } = "";
}
