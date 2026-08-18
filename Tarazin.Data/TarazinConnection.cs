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
    public static string Resolve(IConfiguration? config)
    {
        var value = ResolveRaw(config);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException(
                "No server-side SQL connection is configured. Supply it through the deployment secret store.");

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

    /// <summary>Builds a server-only connection to <c>master</c>.</summary>
    public static string ToMaster(string connectionString)
        => new SqlConnectionStringBuilder(connectionString)
        {
            InitialCatalog = "master"
        }.ConnectionString;
}
