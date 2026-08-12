using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Hermes.ContractTests;

/// <summary>Minimal SQL runner used by contract tests. Executes the same
/// named scripts the webapi runs, directly against the test database.</summary>
public sealed class SqlRunner
{
    private readonly string _connectionString;

    public SqlRunner(string connectionString)
        => _connectionString = connectionString;

    public async Task<bool> CanConnectAsync()
    {
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();
            await conn.ExecuteScalarAsync("SELECT 1");
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<List<string>> QueryColumnsAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        AddParameters(cmd, parameters);
        await using var reader = await cmd.ExecuteReaderAsync();
        var names = new List<string>(reader.FieldCount);
        for (var i = 0; i < reader.FieldCount; i++)
            names.Add(reader.GetName(i));
        return names;
    }

    public async Task<int> ExecuteAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        return await conn.ExecuteAsync(sql, ToDynamicParameters(parameters), commandTimeout: 60);
    }

    public async Task<List<Dictionary<string, object?>>> QueryRowsAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        var rows = await conn.QueryAsync(sql, ToDynamicParameters(parameters), commandTimeout: 60);
        return rows
            .Select(r => (IDictionary<string, object>)r)
            .Select(d => d.ToDictionary(kv => kv.Key, kv => Normalize(kv.Value)))
            .ToList();
    }

    public async Task<object?> ScalarAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        return await conn.ExecuteScalarAsync(sql, ToDynamicParameters(parameters), commandTimeout: 60);
    }

    private static DynamicParameters ToDynamicParameters(IReadOnlyDictionary<string, object?>? parameters)
    {
        var dp = new DynamicParameters();
        if (parameters is null)
            return dp;
        foreach (var (key, value) in parameters)
            dp.Add(key, Normalize(value));
        return dp;
    }

    private static void AddParameters(SqlCommand cmd, IReadOnlyDictionary<string, object?>? parameters)
    {
        if (parameters is null)
            return;
        foreach (var (key, raw) in parameters)
        {
            var value = Normalize(raw);
            cmd.Parameters.Add(new SqlParameter("@" + key, value ?? DBNull.Value));
        }
    }

    /// <summary>Unwraps JsonElement values (from manifest/payload JSON) into
    /// primitive CLR values suitable for ADO.NET parameters.</summary>
    public static object? Normalize(object? value)
    {
        if (value is null)
            return null;
        if (value is not JsonElement je)
            return value;

        return je.ValueKind switch
        {
            JsonValueKind.Null => null,
            JsonValueKind.String => je.GetString(),
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number =>
                je.TryGetInt64(out var l) ? l :
                je.TryGetDecimal(out var m) ? m :
                je.GetDouble(),
            _ => je.GetRawText()
        };
    }
}
