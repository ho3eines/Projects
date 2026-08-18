using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Tarazin.Data;

/// <summary>Server-side provider backed by environment/secret configuration.</summary>
public sealed class ConfigurationSqlConnectionProvider : ISqlConnectionProvider
{
    private readonly string? _connectionString;
    private readonly string _description;
    private readonly string _databaseName;

    public ConfigurationSqlConnectionProvider(IConfiguration configuration)
    {
        try
        {
            _connectionString = TarazinConnection.Resolve(configuration);
            var builder = new SqlConnectionStringBuilder(_connectionString);
            _databaseName = builder.InitialCatalog;
            _description = "اتصال SQL مدیریت‌شدهٔ سمت سرور";
        }
        catch (InvalidOperationException)
        {
            // Configuration is deployment state, not a reason for the DI graph
            // to fail. Keep the host alive so /diag can explain the problem and
            // a secret can be injected/reloaded without an unhandled request.
            _connectionString = null;
            _databaseName = "";
            _description = "اتصال امن پایگاه داده آماده نیست";
        }
    }

    public bool IsAvailable => !string.IsNullOrWhiteSpace(_connectionString);
    public string Description => _description;
    public bool SupportsInitialization => IsAvailable;
    public string DatabaseName => _databaseName;

    public async ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct = default)
    {
        var connectionString = _connectionString
            ?? throw new InvalidOperationException("اتصال امن پایگاه داده آماده نیست.");
        var connection = new SqlConnection(connectionString);
        try
        {
            await connection.OpenAsync(ct).ConfigureAwait(false);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync().ConfigureAwait(false);
            throw;
        }
    }

    public async ValueTask<SqlConnection> OpenMasterConnectionAsync(CancellationToken ct = default)
    {
        var connectionString = _connectionString
            ?? throw new InvalidOperationException("اتصال امن پایگاه داده آماده نیست.");
        var connection = new SqlConnection(TarazinConnection.ToMaster(connectionString));
        try
        {
            await connection.OpenAsync(ct).ConfigureAwait(false);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync().ConfigureAwait(false);
            throw;
        }
    }
}
