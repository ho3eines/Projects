using Microsoft.Data.SqlClient;

namespace Tarazin.Data;

/// <summary>
/// Opens SQL connections without requiring callers to retain a connection string.
/// The web host uses configuration-backed server credentials; MAUI replaces this
/// service with an in-memory, short-lived credential provider after API login.
/// </summary>
public interface ISqlConnectionProvider
{
    /// <summary>True when a credential is currently available.</summary>
    bool IsAvailable { get; }

    /// <summary>A non-secret description suitable for diagnostics.</summary>
    string Description { get; }

    /// <summary>Whether this provider may perform server/database initialization.</summary>
    bool SupportsInitialization { get; }

    /// <summary>Target database name (never contains credentials).</summary>
    string DatabaseName { get; }

    ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct = default);
    ValueTask<SqlConnection> OpenMasterConnectionAsync(CancellationToken ct = default);
}
