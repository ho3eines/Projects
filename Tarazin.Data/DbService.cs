using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Tarazin.Data;

/// <summary>
/// Executes named TSQL scripts against the single <c>TarazinMaster</c>
/// database using Dapper — directly from the Blazor Server process.
///
/// This replaces the old <c>webapi</c> + <c>IRequestService</c> transport:
/// no HTTP, no handshake, no AES envelopes, no tokens passed via URL.
/// The schema is the scope guard: each product module only calls scripts of
/// its own schema, and every script is fully qualified to its own schema.
/// </summary>
public sealed class DbService
{
    private readonly ScriptCatalog _catalog;
    private readonly AuditService _audit;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<DbService> _logger;
    private readonly string _connectionString;

    public DbService(IConfiguration config, ScriptCatalog catalog, AuditService audit,
        ICurrentUser currentUser, ILogger<DbService> logger)
    {
        _catalog = catalog;
        _audit = audit;
        _currentUser = currentUser;
        _logger = logger;
        // خواندن/اعتبارسنجی متمرکز (env → appsettings) با پیام خطای گویا.
        _connectionString = TarazinConnection.Resolve(config);
        // Debug و نه Information: این سرویس scoped است و در وب به‌ازای هر
        // circuit ساخته می‌شود؛ لاگ راه‌اندازی یک‌بار در Program.cs نوشته می‌شود.
        _logger.LogDebug("رشتهٔ اتصال بارگذاری شد: {ConnectionString}",
            TarazinConnection.Mask(_connectionString));
    }

    /// <summary>رشتهٔ اتصال فعال، با رمز ماسک‌شده (برای صفحهٔ عیب‌یابی).</summary>
    public string MaskedConnectionString => TarazinConnection.Mask(_connectionString);

    /// <summary>
    /// تست اتصال: باز کردن یک کانکشن و اجرای <c>SELECT 1</c>.
    /// هرگز استثنا پرتاب نمی‌کند؛ نتیجه را برمی‌گرداند تا UI بتواند نمایش دهد.
    /// </summary>
    public async Task<ConnectionCheckResult> TestConnectionAsync(CancellationToken ct = default)
    {
        var started = DateTime.UtcNow;
        try
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync(ct);
            var one = await conn.ExecuteScalarAsync<int>(
                new CommandDefinition("SELECT 1;", cancellationToken: ct));
            var version = await conn.ExecuteScalarAsync<string>(
                new CommandDefinition("SELECT @@VERSION;", cancellationToken: ct));

            return new ConnectionCheckResult(
                Ok: one == 1,
                Message: "اتصال برقرار است.",
                Server: conn.DataSource,
                Database: conn.Database,
                ServerVersion: version?.Split('\n')[0].Trim(),
                Elapsed: DateTime.UtcNow - started,
                MaskedConnectionString: MaskedConnectionString);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "تست اتصال SQL ناموفق بود");
            return new ConnectionCheckResult(
                Ok: false,
                Message: Describe(ex),
                Server: null,
                Database: null,
                ServerVersion: null,
                Elapsed: DateTime.UtcNow - started,
                MaskedConnectionString: MaskedConnectionString);
        }
    }

    /// <summary>ترجمهٔ خطاهای رایج SQL به پیام فارسی قابل‌فهم.</summary>
    public static string Describe(Exception ex) => ex switch
    {
        SqlException { Number: 18456 } => "احراز هویت SQL ناموفق: نام کاربری یا رمز عبور اشتباه است (Login failed).",
        SqlException { Number: 4060 } => "دسترسی به دیتابیس مقصد ممکن نیست یا دیتابیس وجود ندارد.",
        SqlException { Number: 40615 or 40532 } => "فایروال SQL اجازهٔ اتصال از این IP را نمی‌دهد.",
        SqlException { Number: 53 or -1 or 2 or 258 } =>
            "سرور SQL در دسترس نیست: آدرس/پورت را بررسی کنید (docker compose up -d) و اینکه پورت 1433 باز باشد.",
        SqlException { Number: 4064 } => "دیتابیس پیش‌فرض کاربر قابل باز شدن نیست.",
        SqlException sqlEx => $"خطای SQL {sqlEx.Number}: {sqlEx.Message}",
        _ => ex.Message
    };

    public async Task<IReadOnlyList<T>> QueryAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        var rows = await conn.QueryAsync<T>(new CommandDefinition(sql, parameters, cancellationToken: ct));
        return rows.AsList();
    }

    public async Task<T?> QueryFirstOrDefaultAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        return await conn.QueryFirstOrDefaultAsync<T>(new CommandDefinition(sql, parameters, cancellationToken: ct));
    }

    /// <summary>
    /// Executes a mutating script and **auto-records an audit row** for it
    /// (PRD §5 / ADR-002: every mutating operation is hash-chained in
    /// [central].[AuditLog]). Audit failures never break the business call.
    /// </summary>
    public async Task<int> ExecuteAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        try
        {
            var affected = await conn.ExecuteAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
            await _audit.RecordAsync(schema, scriptName, _currentUser.UserName, "Success", null, ct);
            return affected;
        }
        catch (Exception ex)
        {
            await _audit.RecordAsync(schema, scriptName, _currentUser.UserName, "Error", ex.Message, ct);
            throw;
        }
    }

    public async Task<object?> ScalarAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        var sql = Resolve(schema, scriptName);
        await using var conn = Open();
        return await conn.ExecuteScalarAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
    }

    /// <summary>
    /// اگر دیتابیس مقصد (پیش‌فرض <c>TarazinMaster</c>) وجود نداشته باشد آن را
    /// می‌سازد — با اتصال به <c>master</c>. اسکریپت‌های <c>_Ensure</c> فقط
    /// schema/table می‌سازند و فرض می‌کنند دیتابیس هست؛ در اولین اجرای یک
    /// SQL Server تازه (مثل کانتینر docker) این فرض غلط است و خطای
    /// «Cannot open database» می‌دهد.
    /// </summary>
    public async Task EnsureDatabaseAsync(CancellationToken ct = default)
    {
        var database = TarazinConnection.DatabaseName(_connectionString);
        if (string.IsNullOrWhiteSpace(database))
            return;

        await using var conn = new SqlConnection(TarazinConnection.ToMaster(_connectionString));
        await conn.OpenAsync(ct);

        var exists = await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(*) FROM sys.databases WHERE name = @database;",
            new { database }, cancellationToken: ct));

        if (exists > 0)
            return;

        _logger.LogWarning("دیتابیس {Database} وجود نداشت؛ ساخته می‌شود.", database);

        // نام دیتابیس پارامتر نمی‌پذیرد؛ با QUOTENAME داخل SQL امن می‌شود.
        await conn.ExecuteAsync(new CommandDefinition(
            "DECLARE @sql NVARCHAR(300) = N'CREATE DATABASE ' + QUOTENAME(@database); EXEC(@sql);",
            new { database }, commandTimeout: 120, cancellationToken: ct));
    }

    /// <summary>Runs every <c>{schema}/_Ensure.sql</c> — creates schemas/tables.</summary>
    public async Task EnsureSchemaAsync(CancellationToken ct = default)
    {
        foreach (var schema in _catalog.Schemas)
        {
            if (_catalog.TryGet(schema, "_Ensure", out var ensure))
            {
                await using var conn = Open();
                await conn.ExecuteAsync(new CommandDefinition(ensure, commandTimeout: 120, cancellationToken: ct));
            }
        }
    }

    /// <summary>Runs every <c>{schema}/_Seed.sql</c> — idempotent seed data.</summary>
    public async Task SeedAsync(CancellationToken ct = default)
    {
        foreach (var schema in _catalog.Schemas)
        {
            if (_catalog.TryGet(schema, "_Seed", out var seed))
            {
                await using var conn = Open();
                await conn.ExecuteAsync(new CommandDefinition(seed, commandTimeout: 120, cancellationToken: ct));
            }
        }
    }

    private SqlConnection Open()
    {
        var conn = new SqlConnection(_connectionString);
        conn.Open();
        return conn;
    }

    private string Resolve(string schema, string scriptName)
    {
        if (!_catalog.TryGet(schema, scriptName, out var sql))
            throw new InvalidOperationException(
                $"Named script '{scriptName}' not found for schema '{schema}'.");

        return sql;
    }
}
