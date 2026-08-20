using System.Security.Cryptography;
using Dapper;
using Microsoft.Data.SqlClient;
using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Web;

/// <summary>
/// Simplified MAUI bootstrap (2026-08-20, product-owner decision): the old
/// credential broker (CustomerGuid registry, replay nonces, short-lived tz_m_*
/// SQL principals, refresh/revoke sessions) is removed. This service verifies
/// the user's username/password against [central].[Users] — the exact same
/// check the web login performs — and, on success, returns the server-side
/// SQL connection string from configuration encrypted with AES-256-CBC under
/// a key derived from the login password (SHA-256), so the MAUI client that
/// knows the password can decrypt it in memory. No principal is created, no
/// session is persisted, nothing is stored server-side beyond the audit-free
/// user lookup. Issued passwords and connection strings are never logged.
/// </summary>
public sealed class MobileConnectionService
{
    private readonly ILogger<MobileConnectionService> _logger;
    private readonly string _connectionString;
    private readonly string _database;
    private readonly string _dummyPasswordHash;
    private readonly bool _isAvailable;

    public MobileConnectionService(IConfiguration configuration, ILogger<MobileConnectionService> logger)
    {
        _logger = logger;
        var connectionString = "";
        var database = "";
        var available = false;
        try
        {
            connectionString = TarazinConnection.Resolve(configuration);
            database = new SqlConnectionStringBuilder(connectionString).InitialCatalog;
            available = true;
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            // A missing deployment secret must not break DI or turn every
            // request into an unhandled exception; log the safe signature once
            // so the operator has a server-side trace.
            _logger.LogError("Mobile connection service is unavailable ({ErrorType})", ex.GetType().Name);
        }

        _connectionString = connectionString;
        _database = database;
        // Always run PBKDF2 once per attempt so unknown usernames and wrong
        // passwords take the same code path (no user-enumeration timing gap).
        _dummyPasswordHash = PasswordHasher.Hash(Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
        _isAvailable = available;
    }

    public async Task<MobileLoginOutcome> LoginAsync(MobileLoginRequest request, CancellationToken ct)
    {
        try
        {
            if (!_isAvailable)
                return MobileLoginOutcome.Failure("service_unavailable",
                    "سرویس اتصال موقتاً در دسترس نیست.");

            if (string.IsNullOrWhiteSpace(request.Username) || request.Username.Length > 128 ||
                string.IsNullOrEmpty(request.Password) || request.Password.Length > 1024)
                return MobileLoginOutcome.Rejected(StatusCodes.Status400BadRequest, "invalid_request",
                    "درخواست ورود معتبر نیست.");

            UserRow? user;
            await using (var connection = new SqlConnection(_connectionString))
            {
                await connection.OpenAsync(ct);
                // Same projection as the web login (central/UserAuthenticate.sql)
                // so the MAUI session receives an identical UserRow.
                user = await connection.QueryFirstOrDefaultAsync<UserRow>(new CommandDefinition("""
                    SELECT u.UserId, u.Username, u.PasswordHash, u.DisplayName, u.Role, u.RoleId,
                           r.Title AS RoleTitle, u.IsActive, u.CreatedAt, u.UpdatedAt, u.CreatedBy, u.UpdatedBy
                    FROM [central].[Users] u
                    LEFT JOIN [central].[Roles] r ON r.RoleId = u.RoleId AND r.IsDeleted = 0
                    WHERE u.Username = @Username AND u.IsDeleted = 0;
                    """, new { Username = request.Username.Trim() }, cancellationToken: ct));
            }

            var passwordAccepted = PasswordHasher.Verify(request.Password, user?.PasswordHash ?? _dummyPasswordHash);
            if (user is null || !user.IsActive || !passwordAccepted)
                return MobileLoginOutcome.Rejected(StatusCodes.Status401Unauthorized, "invalid_credentials",
                    "نام کاربری یا رمز عبور صحیح نیست.");

            // Encrypt the server connection string with a key derived from the
            // login password; the client derives the identical key locally.
            var key = ConnectionStringProtector.DeriveKeyFromSecret(request.Password);
            string encrypted;
            try
            {
                encrypted = ConnectionStringProtector.EncryptWithKeyBytes(_connectionString, key);
            }
            finally
            {
                CryptographicOperations.ZeroMemory(key);
            }

            // The hash never leaves the server host.
            user.PasswordHash = "";

            return MobileLoginOutcome.Success(new MobileLoginResponse
            {
                User = user,
                EncryptedConnectionString = encrypted,
                Database = _database
            });
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            LogSafeFailure(ex);
            return MobileLoginOutcome.Failure("service_unavailable",
                "سرویس اتصال موقتاً در دسترس نیست.");
        }
        finally
        {
            request.Password = "";
        }
    }

    /// <summary>Safe diagnostics only: exception type and SQL error *numbers*; raw messages are never logged.</summary>
    private void LogSafeFailure(Exception ex)
    {
        var sqlNumber = 0;
        var sqlNumbers = "";
        for (var current = ex; current is not null; current = current.InnerException)
        {
            if (current is SqlException sql)
            {
                sqlNumber = sql.Number;
                sqlNumbers = string.Join(",", sql.Errors.Cast<SqlError>().Select(e => e.Number).Distinct());
                break;
            }
        }
        _logger.LogError("Mobile connection login failed ({ErrorType}, SqlNumber={SqlNumber}, SqlNumbers={SqlNumbers})",
            ex.GetType().Name, sqlNumber, sqlNumbers);
    }
}

public sealed record MobileLoginOutcome(int StatusCode, MobileLoginResponse? Response, MobileConnectionError? Error)
{
    public static MobileLoginOutcome Success(MobileLoginResponse response)
        => new(StatusCodes.Status200OK, response, null);

    public static MobileLoginOutcome Rejected(int statusCode, string code, string message)
        => new(statusCode, null, new MobileConnectionError { Code = code, Message = message });

    public static MobileLoginOutcome Failure(string code, string message)
        => new(StatusCodes.Status503ServiceUnavailable, null,
            new MobileConnectionError { Code = code, Message = message });
}
