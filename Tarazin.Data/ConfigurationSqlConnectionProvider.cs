using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Tarazin.Data;

/// <summary>Server-side provider backed by environment/secret configuration.</summary>
public sealed class ConfigurationSqlConnectionProvider : ISqlConnectionProvider
{
    private readonly string _connectionString;
    private readonly string _description;
    private readonly string _databaseName;

    public ConfigurationSqlConnectionProvider(IConfiguration configuration)
    {
        _connectionString = TarazinConnection.Resolve(configuration);
        var builder = new SqlConnectionStringBuilder(_connectionString);
        _databaseName = builder.InitialCatalog;
        _description = "اتصال SQL مدیریت‌شدهٔ سمت سرور";
    }

    public bool IsAvailable => true;
    public string Description => _description;
    public bool SupportsInitialization => true;
    public string DatabaseName => _databaseName;

    public async ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct = default)
    {
        var connection = new SqlConnection(_connectionString);
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
        var connection = new SqlConnection(TarazinConnection.ToMaster(_connectionString));
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
