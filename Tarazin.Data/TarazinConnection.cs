using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Tarazin.Data;

/// <summary>
/// Server-side SQL connection configuration. Raw connection material is returned
/// only to the server-side providers that must open SQL connections; it is never
/// exposed through diagnostics, logging, UI, or MAUI configuration.
/// </summary>
public static class TarazinConnection
{
    public const string Name = "DefaultConnection";

    /// <summary>
    /// Optional server deployment variable. MAUI startup intentionally does not
    /// load this variable and uses its HTTPS <c>ServerEndpoint</c> instead.
    /// </summary>
    public const string EnvVariable = "TARAZIN_SQL_CONNECTION";

    /// <summary>Reads and validates the server-side deployment secret.</summary>
    /// <remarks>
    /// Supports encrypted storage in <c>appsettings.json</c>: when the configured
    /// value starts with <c>ENC:</c> it is decrypted with
    /// <see cref="ConnectionStringProtector"/> using the static key from
    /// <c>TARAZIN_ENCRYPTION_KEY</c> or <c>ConnectionProtection:Key</c>. This
    /// lets the connection string live encrypted in <c>appsettings.json</c> and
    /// only exist in plaintext inside the server process memory — and, when
    /// requested via the authenticated broker, be re-encrypted per-session for
    /// delivery to MAUI.
    /// </remarks>
    public static string Resolve(IConfiguration? config)
    {
        var value = ResolveRaw(config);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException(
                "No server-side SQL connection is configured. Supply it through the deployment secret store.");

        // Encrypted-at-rest in appsettings.json: ENC:<Base64(IV+Ciphertext)>
        // Decrypt before any further validation so the builder sees plaintext.
        value = TryDecryptIfNeeded(value.Trim(), config);

        try
        {
            var builder = new SqlConnectionStringBuilder(value);
            if (string.IsNullOrWhiteSpace(builder.DataSource) ||
                string.IsNullOrWhiteSpace(builder.InitialCatalog))
            {
                throw new InvalidOperationException(
                    "The server-side SQL connection configuration is incomplete.");
            }

            // Server-to-SQL traffic is sensitive too. Do not let a deployment
            // secret silently downgrade encryption or certificate validation.
            // Certificate validation is always enforced — ADR-004: no target
            // may add a certificate bypass, Development included. For a local
            // SQL Server with a self-signed certificate, install a trusted
            // certificate instead.
            builder.Encrypt = true;
            builder.TrustServerCertificate = false;
            builder.PersistSecurityInfo = false;

            if (builder.ConnectTimeout <= 0 || builder.ConnectTimeout > 60)
                builder.ConnectTimeout = 30;
            if (!builder.ShouldSerialize("Application Name"))
                builder.ApplicationName = "Tarazin";

            return builder.ConnectionString;
        }
        catch (ArgumentException)
        {
            // Provider parser messages can echo malformed input. Never retain
            // them as either the message or InnerException.
            throw new InvalidOperationException(
                "The server-side SQL connection configuration is invalid.");
        }
    }

    private static string? ResolveRaw(IConfiguration? config)
    {
        var fromEnvironment = Environment.GetEnvironmentVariable(EnvVariable);
        if (!string.IsNullOrWhiteSpace(fromEnvironment))
            return fromEnvironment;

        return config?.GetConnectionString(Name);
    }


    private static string TryDecryptIfNeeded(string value, IConfiguration? config)
    {
        if (!ConnectionStringProtector.IsEncrypted(value))
            return value;

        var key = ConnectionStringProtector.ResolveStaticKey(config);
        if (string.IsNullOrWhiteSpace(key))
            throw new InvalidOperationException(
                "The SQL connection string is encrypted (ENC:) but no decryption key is configured. Set TARAZIN_ENCRYPTION_KEY or ConnectionProtection:Key (Base64 32-byte key).");

        try
        {
            return ConnectionStringProtector.Decrypt(value, key);
        }
        catch (Exception ex) when (ex is ArgumentException or System.Security.Cryptography.CryptographicException or FormatException)
        {
            throw new InvalidOperationException(
                "The encrypted SQL connection string could not be decrypted. Verify the key and ENC: payload.", ex);
        }
    }

    /// <summary>Builds a server-only connection to <c>master</c>.</summary>
    public static string ToMaster(string connectionString)
        => new SqlConnectionStringBuilder(connectionString)
        {
            InitialCatalog = "master"
        }.ConnectionString;
}
