using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace Tarazin.Data;

/// <summary>
/// Executes named TSQL scripts against the single <c>TarazinMaster</c>
/// database using Dapper in the current host process. The Web host obtains its
/// connection from server-only configuration; MAUI bootstraps the same server
/// connection string once from the Web host (encrypted, password-derived key)
/// and keeps it in memory.
///
/// There is no business-data HTTP transport. The schema is the scope guard:
/// each product module only calls scripts of its own schema, and every script
/// is fully qualified to its own schema.
/// </summary>
public sealed class DbService
{
    private readonly ScriptCatalog _catalog;
    private readonly AuditService _audit;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<DbService> _logger;
    private readonly ISqlConnectionProvider _connectionProvider;

    public DbService(ISqlConnectionProvider connectionProvider, ScriptCatalog catalog, AuditService audit,
        ICurrentUser currentUser, ILogger<DbService> logger)
    {
        _connectionProvider = connectionProvider;
        _catalog = catalog;
        _audit = audit;
        _currentUser = currentUser;
        _logger = logger;
    }

    /// <summary>Non-secret connection destination for diagnostics.</summary>
    public string ConnectionDescription => _connectionProvider.Description;
    public bool IsConnectionAvailable => _connectionProvider.IsAvailable;
    public bool UsesTemporaryCredential => !_connectionProvider.SupportsInitialization;
    public int? CurrentCompanyId => _currentUser.ActiveCompanyId;

    /// <summary>
    /// تست اتصال: باز کردن یک کانکشن و اجرای <c>SELECT 1</c>.
    /// خطاهای اتصال را به نتیجهٔ کنترل‌شده تبدیل می‌کند؛ لغو درخواستی caller حفظ می‌شود.
    /// </summary>
    public async Task<ConnectionCheckResult> TestConnectionAsync(CancellationToken ct = default)
    {
        var started = DateTime.UtcNow;
        try
        {
            await using var conn = await OpenConnectionAsync(ct);
            var one = await conn.ExecuteScalarAsync<int>(
                new CommandDefinition("SELECT 1;", cancellationToken: ct));
            return new ConnectionCheckResult(
                Ok: one == 1,
                Message: "اتصال برقرار است.",
                Elapsed: DateTime.UtcNow - started,
                ProviderDescription: ConnectionDescription);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            // شمارهٔ SqlException غیرمحرمانه است و برای عیب‌یابی ثبت می‌شود؛
            // متن/رشتهٔ اتصال خام هرگز log نمی‌شود.
            _logger.LogError("SQL connection test failed ({ErrorType}, SqlNumber={SqlNumber})",
                ex.GetType().Name, FindSqlNumber(ex));
            return new ConnectionCheckResult(
                Ok: false,
                Message: Describe(ex),
                Elapsed: DateTime.UtcNow - started,
                ProviderDescription: ConnectionDescription);
        }
    }

    /// <summary>Maps failures to safe messages without returning exception text.</summary>
    public static string Describe(Exception ex)
    {
        if (ex is SafeDataException safe)
            return safe.Message;

        if (ex is SqlException sql)
        {
            // شکست دست‌دادن TLS/گواهی ممکن است با کد منفی Schannel یا با متن
            // «certificate» بیاید؛ پیش از هر نگاشت دیگری شناسایی می‌شود تا
            // اپراتور به‌جای پیام عمومی، راه‌حل دقیق (اعتماد به گواهی) را ببیند.
            if (IsTlsCertificateFailure(sql))
                return "گواهی SQL Server توسط این دستگاه تأیید نمی‌شود (TLS).";

            return sql.Number switch
            {
                18456 => "اعتبار اتصال پایگاه داده پذیرفته نشد.",
                4060 or 4064 => "دسترسی به پایگاه داده مقصد ممکن نیست.",
                40615 or 40532 => "فایروال پایگاه داده اتصال را نپذیرفت.",
                // named pipes/TCP: سرور یافت نشد، اتصال رد شد یا مهلت تمام شد.
                53 or 2 or 258 or 10060 or 10061 or 11001 => "سرویس پایگاه داده در دسترس نیست.",
                _ => "عملیات پایگاه داده انجام نشد."
            };
        }

        if (IsTlsCertificateFailure(ex))
            return "گواهی SQL Server توسط این دستگاه تأیید نمی‌شود (TLS).";

        return ex switch
        {
            InvalidOperationException => "اتصال امن پایگاه داده آماده نیست.",
            OperationCanceledException => "عملیات لغو شد.",
            _ => "خطای غیرمنتظره‌ای هنگام دسترسی به داده رخ داد."
        };
    }

    /// <summary>
    /// تشخیص شکست دست‌دادن TLS/گواهی که ممکن است به‌صورت SqlException با کد منفی
    /// Schannel یا داخل InnerException (AuthenticationException/Win32) ظاهر شود.
    /// فقط برای طبقه‌بندی استفاده می‌شود؛ متن خام هرگز برگردانده یا ثبت نمی‌شود.
    /// </summary>
    private static bool IsTlsCertificateFailure(Exception? exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is SqlException { Number: -2146893019 or -2146893013 or -2146893007 or -2146762487 })
                return true;
            if (current.Message.IndexOf("certificate", StringComparison.OrdinalIgnoreCase) >= 0)
                return true;
        }
        return false;
    }

    private static int? FindSqlNumber(Exception? exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is SqlException sql)
                return sql.Number;
        }
        return null;
    }

    public async Task<IReadOnlyList<T>> QueryAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        try
        {
            var sql = Resolve(schema, scriptName);
            await using var conn = await OpenConnectionAsync(ct);
            var rows = await conn.QueryAsync<T>(new CommandDefinition(sql, parameters, cancellationToken: ct));
            return rows.AsList();
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw SafeFailure(schema, scriptName, ex);
        }
    }

    public async Task<T?> QueryFirstOrDefaultAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        try
        {
            var sql = Resolve(schema, scriptName);
            await using var conn = await OpenConnectionAsync(ct);
            return await conn.QueryFirstOrDefaultAsync<T>(new CommandDefinition(sql, parameters, cancellationToken: ct));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw SafeFailure(schema, scriptName, ex);
        }
    }

    /// <summary>
    /// Executes a script returning multiple result sets and exposes each set
    /// through a reader callback. The callback receives a Dapper
    /// <see cref="SqlMapper.GridReader"/> whose <c>Read&lt;T&gt;</c> calls are
    /// consumed in order of the result sets.
    /// </summary>
    public async Task QueryMultipleAsync(
        string schema, string scriptName, object? parameters,
        Func<SqlMapper.GridReader, Task> read, CancellationToken ct = default)
    {
        try
        {
            var sql = Resolve(schema, scriptName);
            await using var conn = await OpenConnectionAsync(ct);
            var grid = await conn.QueryMultipleAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
            using (grid)
            {
                await read(grid);
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw SafeFailure(schema, scriptName, ex);
        }
    }

    /// <summary>
    /// Executes a mutating script and **auto-records an audit row** for it
    /// in [central].[AuditLog]. The current predecessor metadata is retained,
    /// but cryptographic chain correctness is an open release gate because
    /// RowHash does not yet commit PrevHash and writes are not serialized.
    /// Audit failures never break the business call.
    /// </summary>
    public async Task<int> ExecuteAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        try
        {
            var sql = Resolve(schema, scriptName);
            await using var conn = await OpenConnectionAsync(ct);
            var affected = await conn.ExecuteAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
            await _audit.RecordAsync(schema, scriptName, _currentUser.UserName,
                ResolveAuditCompanyId(schema, scriptName, parameters), "Success", null, ct);
            return affected;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            await _audit.RecordAsync(schema, scriptName, _currentUser.UserName,
                ResolveAuditCompanyId(schema, scriptName, parameters), "Error", Describe(ex), ct);
            throw SafeFailure(schema, scriptName, ex);
        }
    }

    /// <summary>
    /// Executes a mutating script that returns one result row and records the
    /// same audit entry as <see cref="ExecuteAsync"/>. Use this for atomic
    /// create/allocate scripts whose generated values must be returned.
    /// </summary>
    public async Task<T?> ExecuteReturningAsync<T>(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        try
        {
            var sql = Resolve(schema, scriptName);
            await using var conn = await OpenConnectionAsync(ct);
            var result = await conn.QueryFirstOrDefaultAsync<T>(
                new CommandDefinition(sql, parameters, cancellationToken: ct));
            await _audit.RecordAsync(schema, scriptName, _currentUser.UserName,
                ResolveAuditCompanyId(schema, scriptName, parameters, result), "Success", null, ct);
            return result;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            await _audit.RecordAsync(schema, scriptName, _currentUser.UserName,
                ResolveAuditCompanyId(schema, scriptName, parameters), "Error", Describe(ex), ct);
            throw SafeFailure(schema, scriptName, ex);
        }
    }

    public async Task<object?> ScalarAsync(
        string schema, string scriptName, object? parameters = null, CancellationToken ct = default)
    {
        try
        {
            var sql = Resolve(schema, scriptName);
            await using var conn = await OpenConnectionAsync(ct);
            return await conn.ExecuteScalarAsync(new CommandDefinition(sql, parameters, cancellationToken: ct));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw SafeFailure(schema, scriptName, ex);
        }
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
        if (!_connectionProvider.SupportsInitialization)
            throw new InvalidOperationException("This connection cannot initialize a database.");

        var database = _connectionProvider.DatabaseName;
        if (string.IsNullOrWhiteSpace(database))
            return;

        await using var conn = await _connectionProvider.OpenMasterConnectionAsync(ct);

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
        // ترتیب اجرا مهم است: اسکیمای central (کاربران، شرکت‌ها، سال‌های مالی
        // و جداول دسترسی) باید پیش از بقیه ساخته شود چون اسکیماهای کسب‌وکار
        // (مثل accounting) روی central.Companies / central.FiscalYears
        // خارج‌کلید دارند. بدون این ترتیب، روی دیتابیس تازه خطای
        // «FK references invalid table 'central.Companies'» رخ می‌دهد.
        var schemas = _catalog.Schemas
            .OrderBy(s => string.Equals(s, "central", StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(s => s, StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var schema in schemas)
        {
            if (_catalog.TryGet(schema, "_Ensure", out var ensure))
            {
                Console.WriteLine($"[init-ensure] {schema}");
                try
                {
                    await using var conn = await OpenConnectionAsync(ct);
                    await ExecuteBatchesAsync(conn, ensure, ct);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[init-ensure-FAIL] {schema}: {Describe(ex)}");
                    throw;
                }
            }
        }
    }

    /// <summary>Runs every <c>{schema}/_Seed.sql</c> — idempotent seed data.</summary>
    public async Task SeedAsync(CancellationToken ct = default)
    {
        // هم‌راستا با EnsureSchemaAsync: ابتدا central (شرکت/سال/دسترسی‌ها)
        // تا بذرِ اسکیماهای وابسته، مقادیر صحیحِ خارج‌کلید را ببیند.
        var schemas = _catalog.Schemas
            .OrderBy(s => s switch
            {
                "central" => 0,
                "accounting" => 1,
                "inventory" => 2,
                "goldshop" => 3,
                _ => 10
            })
            .ThenBy(s => s, StringComparer.OrdinalIgnoreCase)
            .ToList();

        foreach (var schema in schemas)
        {
            if (_catalog.TryGet(schema, "_Seed", out var seed))
            {
                try
                {
                    await using var conn = await OpenConnectionAsync(ct);
                    await ExecuteBatchesAsync(conn, seed, ct);
                    _logger.LogWarning("[seed-ok] {Schema} _Seed", schema);
                }
                catch (Exception ex)
                {
                    _logger.LogError("[seed-fail] {Schema} _Seed: {Err}", schema, DbService.Describe(ex));
                    throw;
                }
            }
        }
    }

    /// <summary>
    /// Executes a script one <c>GO</c>-delimited batch at a time. SSMS-style
    /// scripts contain <c>GO</c> lines that are not valid TSQL; splitting here
    /// keeps them from reaching SQL Server (and honours batch-boundary rules).
    /// </summary>
    private async Task ExecuteBatchesAsync(SqlConnection conn, string sql, CancellationToken ct)
    {
        // Filtered indexes require these SET options for both DDL and DML.
        // Explicitly set them because sqlcmd/ADO.NET defaults differ.
        await conn.ExecuteAsync(new CommandDefinition(
            "SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;",
            cancellationToken: ct));
        foreach (var batch in SqlScript.SplitBatches(sql))
        {
            await conn.ExecuteAsync(new CommandDefinition(batch, commandTimeout: 120, cancellationToken: ct));
        }
    }

    private int? ResolveAuditCompanyId(
        string schema,
        string scriptName,
        object? parameters,
        object? result = null)
    {
        // Explicit operation context wins over ambient UI state (notably while
        // switching active company). A generic returned NewId is not a company
        // identifier: only the explicit company-creation script may use it for
        // audit ownership. Other create scripts return unrelated entity IDs.
        var createdCompanyId =
            string.Equals(schema, "central", StringComparison.OrdinalIgnoreCase) &&
            string.Equals(scriptName, "CompanyUpsert", StringComparison.OrdinalIgnoreCase)
                ? ReadPositiveInt(result, "NewId")
                : null;

        return ReadPositiveInt(parameters, "ActiveCompanyId")
            ?? ReadPositiveInt(parameters, "CompanyId")
            ?? ReadPositiveInt(result, "CompanyId")
            ?? createdCompanyId
            ?? _currentUser.ActiveCompanyId;
    }

    private static int? ReadPositiveInt(object? source, string name)
    {
        if (source is null)
            return null;

        object? value = null;
        if (source is DynamicParameters dynamicParameters)
        {
            var parameterName = dynamicParameters.ParameterNames.FirstOrDefault(candidate =>
                string.Equals(candidate.TrimStart('@'), name, StringComparison.OrdinalIgnoreCase));
            if (parameterName is not null)
            {
                try { value = dynamicParameters.Get<object?>(parameterName); }
                catch { return null; }
            }
        }
        else if (source is IReadOnlyDictionary<string, object?> readOnlyDictionary)
        {
            var pair = readOnlyDictionary.FirstOrDefault(candidate =>
                string.Equals(candidate.Key.TrimStart('@'), name, StringComparison.OrdinalIgnoreCase));
            value = pair.Value;
        }
        else if (source is IDictionary<string, object?> dictionary)
        {
            var pair = dictionary.FirstOrDefault(candidate =>
                string.Equals(candidate.Key.TrimStart('@'), name, StringComparison.OrdinalIgnoreCase));
            value = pair.Value;
        }
        else
        {
            value = source.GetType().GetProperties()
                .FirstOrDefault(property => string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase))?
                .GetValue(source);
        }

        if (value is null)
            return null;
        try
        {
            var converted = Convert.ToInt32(value);
            return converted > 0 ? converted : null;
        }
        catch
        {
            return null;
        }
    }

    private async ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct)
    {
        var connection = await _connectionProvider.OpenConnectionAsync(ct);
        try
        {
            // Reset on every pooled checkout. Mobile RLS derives its immutable
            // company from the generated login; the Web host uses active context
            // so defaults on newly tenant-owned child tables preserve behavior.
            await connection.ExecuteAsync(new CommandDefinition(
                "EXEC sys.sp_set_session_context @key=N'TarazinCompanyId', @value=@CompanyId;",
                new { CompanyId = _currentUser.ActiveCompanyId }, cancellationToken: ct));
            return connection;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    private SafeDataException SafeFailure(string schema, string scriptName, Exception ex)
    {
        if (ex is SafeDataException safe)
            return safe;
        _logger.LogWarning("Data operation {Schema}/{Script} failed ({ErrorType}, SqlNumber={SqlNumber})",
            schema, scriptName, ex.GetType().Name, FindSqlNumber(ex));
        return new SafeDataException(Describe(ex));
    }

    private string Resolve(string schema, string scriptName)
    {
        if (!_catalog.TryGet(schema, scriptName, out var sql))
            throw new InvalidOperationException(
                $"Named script '{scriptName}' not found for schema '{schema}'.");

        return sql;
    }
}

/// <summary>Client-displayable database failure with no raw SQL exception details.</summary>
public sealed class SafeDataException : Exception
{
    public SafeDataException(string safeMessage) : base(safeMessage) { }
    public SafeDataException(string safeMessage, Exception inner) : base(safeMessage, inner) { }
}
