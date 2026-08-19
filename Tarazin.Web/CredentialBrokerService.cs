using System.Data;
using System.Security.Cryptography;
using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Web;

/// <summary>
/// Server-only broker for replay-protected authentication and revocable,
/// short-lived SQL principals. No issued password or bearer token is logged or
/// persisted in plaintext.
/// </summary>
public sealed class CredentialBrokerService
{
    private static readonly string[] RuntimeSchemas =
    {
        "accounting", "assets", "bi", "branch", "central", "currency",
        "goldshop", "inventory", "payroll", "store", "treasury"
    };

    private readonly ILogger<CredentialBrokerService> _logger;
    private readonly string _issuerConnectionString;
    private readonly string _database;
    private readonly string _publicServer;
    private readonly TimeSpan _credentialLifetime;
    private readonly TimeSpan _sessionLifetime;
    private readonly TimeSpan _requestSkew;
    private readonly TimeSpan _cleanupTimeout;
    private readonly string _dummyPasswordHash;
    private readonly bool _isAvailable;
    private readonly string _unavailabilityCode;

    public CredentialBrokerService(IConfiguration configuration, ILogger<CredentialBrokerService> logger)
    {
        _logger = logger;

        var issuerConnectionString = "";
        var database = "";
        var publicServer = "";
        var credentialLifetime = TimeSpan.Zero;
        var sessionLifetime = TimeSpan.Zero;
        var requestSkew = TimeSpan.Zero;
        var cleanupTimeout = TimeSpan.Zero;
        var dummyPasswordHash = "";
        var isAvailable = false;
        var unavailabilityCode = "broker_not_configured";

        try
        {
            issuerConnectionString = TarazinConnection.Resolve(configuration);
            var builder = new SqlConnectionStringBuilder(issuerConnectionString);
            database = builder.InitialCatalog;

            // A MAUI device must be given the SQL endpoint it can actually
            // reach. Never infer it from the Web host's private/local issuer
            // connection string (for example Data Source=. on the server).
            var configuredPublicServer = configuration["CredentialBroker:PublicSqlServer"]?.Trim();
            if (string.IsNullOrWhiteSpace(configuredPublicServer))
                throw new InvalidOperationException("CredentialBroker:PublicSqlServer must be configured.");
            publicServer = ValidatePublicServer(configuredPublicServer);

            credentialLifetime = TimeSpan.FromMinutes(Clamp(configuration, "CredentialBroker:CredentialLifetimeMinutes", 5, 2, 15));
            sessionLifetime = TimeSpan.FromMinutes(Clamp(configuration, "CredentialBroker:SessionLifetimeMinutes", 30, 5, 120));
            requestSkew = TimeSpan.FromSeconds(Clamp(configuration, "CredentialBroker:RequestTimestampWindowSeconds", 90, 30, 300));
            cleanupTimeout = TimeSpan.FromSeconds(Clamp(configuration, "CredentialBroker:CleanupTimeoutSeconds", 20, 5, 60));
            dummyPasswordHash = PasswordHasher.Hash(Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
            isAvailable = true;
            unavailabilityCode = "";
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
        {
            // Missing deployment secrets or a missing public SQL endpoint must
            // not break DI or turn every request into an unhandled exception.
            // The client receives a controlled, actionable 503 instead.
        }

        _issuerConnectionString = issuerConnectionString;
        _database = database;
        _publicServer = publicServer;
        _credentialLifetime = credentialLifetime;
        _sessionLifetime = sessionLifetime;
        _requestSkew = requestSkew;
        _cleanupTimeout = cleanupTimeout;
        _dummyPasswordHash = dummyPasswordHash;
        _isAvailable = isAvailable;
        _unavailabilityCode = unavailabilityCode;
    }

    public async Task<BrokerResult> LoginAsync(MobileConnectionRequest request, CancellationToken ct)
    {
        if (!_isAvailable)
            return BrokerResult.Unavailable(_unavailabilityCode);

        try
        {
            return await LoginCoreAsync(request, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            LogSafeFailure("login", ex);
            return InfrastructureFailure(ex);
        }
        finally
        {
            request.Password = "";
        }
    }

    private async Task<BrokerResult> LoginCoreAsync(MobileConnectionRequest request, CancellationToken ct)
    {
        if (!IsValidRequest(request.CustomerGuid, request.Nonce, request.TimestampUtc) ||
            string.IsNullOrWhiteSpace(request.Username) || request.Username.Length > 128 ||
            string.IsNullOrEmpty(request.Password) || request.Password.Length > 1024)
            return BrokerResult.Rejected("invalid_request", "درخواست ورود معتبر نیست.");

        await using var connection = await OpenIssuerConnectionAsync(ct);
        if (!await ConsumeNonceAsync(connection, request.Nonce, ct))
            return BrokerResult.Rejected("replayed_request", "این درخواست قبلاً استفاده شده است.");

        var user = await connection.QueryFirstOrDefaultAsync<BrokerUser>(new CommandDefinition("""
            SELECT u.UserId, u.Username, u.PasswordHash, u.DisplayName, u.Role, u.RoleId,
                   r.Title AS RoleTitle, u.IsActive
            FROM [central].[Users] u
            LEFT JOIN [central].[Roles] r ON r.RoleId = u.RoleId AND r.IsDeleted = 0
            WHERE u.Username = @Username AND u.IsDeleted = 0;
            """, new { Username = request.Username.Trim() }, cancellationToken: ct));

        // Always run PBKDF2 to reduce username-enumeration timing differences.
        var passwordAccepted = PasswordHasher.Verify(request.Password, user?.PasswordHash ?? _dummyPasswordHash);
        if (user is null || !user.IsActive || !passwordAccepted)
            return BrokerResult.Rejected("invalid_credentials", "نام کاربری یا رمز عبور صحیح نیست.");

        var customer = await connection.QueryFirstOrDefaultAsync<BrokerCustomer>(new CommandDefinition("""
            SELECT c.CredentialCustomerId AS CustomerId, c.CustomerGuid, c.CompanyId,
                   c.IsActive, CAST(0 AS BIT) AS IsDeleted,
                   c.CredentialAccessEnabled, co.IsActive AS CompanyIsActive,
                   co.IsDeleted AS CompanyIsDeleted,
                   CAST(CASE WHEN u.Role = N'Admin' OR EXISTS (
                       SELECT 1 FROM [central].[UserCompanies] uc
                       WHERE uc.UserId = u.UserId AND uc.CompanyId = c.CompanyId)
                       THEN 1 ELSE 0 END AS BIT) AS IsAuthorized
            FROM [central].[CredentialCustomers] c
            JOIN [central].[Companies] co ON co.CompanyId = c.CompanyId
            CROSS JOIN [central].[Users] u
            WHERE c.CustomerGuid = @CustomerGuid AND u.UserId = @UserId;
            """, new { request.CustomerGuid, user.UserId }, cancellationToken: ct));

        if (customer is null)
            return BrokerResult.Rejected("customer_not_found", "مشتری یافت نشد یا مجاز نیست.");
        if (!customer.IsActive || customer.IsDeleted || !customer.CredentialAccessEnabled ||
            !customer.CompanyIsActive || customer.CompanyIsDeleted)
            return BrokerResult.Rejected("customer_inactive", "دسترسی این مشتری فعال نیست.");
        if (!customer.IsAuthorized)
            return BrokerResult.Rejected("customer_not_authorized", "کاربر برای این مشتری مجاز نیست.");

        IssuedPrincipal? issued = null;
        Guid? sessionId = null;
        try
        {
            var access = await LoadAccessProfileAsync(connection, user.RoleId, user.Role, ct);
            issued = PlanPrincipal();
            var now = DateTimeOffset.UtcNow;
            var sessionExpires = now.Add(_sessionLifetime);
            var token = CreateOpaqueSecret(32);
            sessionId = Guid.NewGuid();

            // Persist the issuance before creating the server login. A crash or
            // canceled request can therefore never leave an untracked principal.
            await connection.ExecuteAsync(new CommandDefinition("""
                INSERT INTO [central].[MobileCredentialSessions]
                    (SessionId, SessionFamilyId, TokenHash, CustomerGuid, CustomerId,
                     CompanyId, UserId, SqlLoginName, CredentialExpiresAt,
                     SessionExpiresAt, CreatedAt)
                VALUES
                    (@SessionId, @SessionId, @TokenHash, @CustomerGuid, @CustomerId,
                     @CompanyId, @UserId, @SqlLoginName, @CredentialExpiresAt,
                     @SessionExpiresAt, SYSUTCDATETIME());
                """, new
                {
                    SessionId = sessionId.Value,
                    TokenHash = Sha256(token),
                    request.CustomerGuid,
                    customer.CustomerId,
                    customer.CompanyId,
                    user.UserId,
                    issued.LoginName,
                    issued.ExpiresAtUtc,
                    SessionExpiresAt = sessionExpires
                }, cancellationToken: ct));

            await CreatePrincipalAsync(issued, access, ct);
            var activated = await connection.ExecuteAsync(new CommandDefinition("""
                UPDATE [central].[MobileCredentialSessions]
                SET ActivatedAt = SYSUTCDATETIME()
                WHERE SessionId = @SessionId AND ActivatedAt IS NULL AND RevokedAt IS NULL;
                """, new { SessionId = sessionId.Value }, cancellationToken: ct));
            if (activated != 1)
                throw new InvalidOperationException("Pending credential session could not be activated.");

            return BrokerResult.Success(CreateResponse(user, customer.CustomerGuid, token,
                sessionExpires, issued));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            if (sessionId is not null)
                await BestEffortMarkRevokedAsync(sessionId.Value);
            if (issued is not null)
                await BestEffortRevokePrincipalAsync(issued.LoginName);
            throw;
        }
        catch (Exception ex)
        {
            if (sessionId is not null)
                await BestEffortMarkRevokedAsync(sessionId.Value);
            if (issued is not null)
                await BestEffortRevokePrincipalAsync(issued.LoginName);
            LogSafeFailure("issue", ex);
            return InfrastructureFailure(ex);
        }
        finally
        {
            request.Password = "";
        }
    }

    public async Task<BrokerResult> RefreshAsync(
        MobileConnectionRefreshRequest request,
        string bearerToken,
        CancellationToken ct)
    {
        if (!_isAvailable)
            return BrokerResult.Unavailable(_unavailabilityCode);

        try
        {
            return await RefreshCoreAsync(request, bearerToken, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            LogSafeFailure("refresh", ex);
            return InfrastructureFailure(ex);
        }
    }

    private async Task<BrokerResult> RefreshCoreAsync(
        MobileConnectionRefreshRequest request,
        string bearerToken,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(bearerToken) ||
            !IsValidRequest(request.CustomerGuid, request.Nonce, request.TimestampUtc))
            return BrokerResult.Rejected("invalid_token", "نشست اتصال معتبر نیست.");

        await using var connection = await OpenIssuerConnectionAsync(ct);
        if (!await ConsumeNonceAsync(connection, request.Nonce, ct))
            return BrokerResult.Rejected("replayed_request", "این درخواست قبلاً استفاده شده است.");

        var tokenHash = Sha256(bearerToken);
        var familyId = await FindSessionFamilyAsync(connection, tokenHash, ct);
        if (familyId is null)
            return BrokerResult.Rejected("invalid_token", "نشست اتصال معتبر یا فعال نیست.");

        // A database-scoped family lock linearizes refreshes in this token
        // lineage, including requests made with an already-rotated ancestor.
        // Revoke also attempts this lock, but never depends on acquiring it.
        // The session-owned lock is released with this issuer connection.
        if (!await AcquireFamilyLockAsync(connection, familyId.Value, ct))
            return BrokerResult.Unavailable();

        var session = await LoadSessionAsync(connection, tokenHash, ct);
        if (session is null)
        {
            var principals = await MarkFamilyRevokedAsync(connection, familyId.Value, ct);
            await BestEffortRevokePrincipalsAsync(principals);
            return BrokerResult.Rejected("invalid_token", "نشست اتصال معتبر یا فعال نیست.");
        }

        var now = DateTimeOffset.UtcNow;
        if (session.ActivatedAt is null || session.RevokedAt is not null ||
            session.SessionExpiresAt <= now || session.CustomerGuid != request.CustomerGuid)
            return BrokerResult.Rejected("invalid_token", "نشست اتصال معتبر یا فعال نیست.");

        if (!session.UserIsActive || !session.CustomerIsActive || session.CustomerIsDeleted ||
            !session.CredentialAccessEnabled || !session.CompanyIsActive ||
            session.CompanyIsDeleted || !session.IsAuthorized)
        {
            var principals = await MarkFamilyRevokedAsync(connection, session.SessionFamilyId, ct);
            await BestEffortRevokePrincipalsAsync(principals);
            return BrokerResult.Rejected("authorization_expired", "مجوز مشتری یا کاربر منقضی شده است.");
        }

        IssuedPrincipal? replacement = null;
        Guid? replacementSessionId = null;
        try
        {
            var access = await LoadAccessProfileAsync(connection, session.RoleId, session.Role, ct);
            replacement = PlanPrincipal();
            var newToken = CreateOpaqueSecret(32);
            replacementSessionId = Guid.NewGuid();

            // The successor stays pending (and therefore fails every RLS
            // predicate) until its principal exists and the old-row revoke plus
            // successor activation commit atomically below.
            await connection.ExecuteAsync(new CommandDefinition("""
                INSERT INTO [central].[MobileCredentialSessions]
                    (SessionId, SessionFamilyId, TokenHash, CustomerGuid, CustomerId,
                     CompanyId, UserId, SqlLoginName, CredentialExpiresAt,
                     SessionExpiresAt, CreatedAt)
                VALUES
                    (@SessionId, @SessionFamilyId, @TokenHash, @CustomerGuid, @CustomerId,
                     @CompanyId, @UserId, @SqlLoginName, @CredentialExpiresAt,
                     @SessionExpiresAt, SYSUTCDATETIME());
                """, new
                {
                    SessionId = replacementSessionId.Value,
                    session.SessionFamilyId,
                    TokenHash = Sha256(newToken),
                    session.CustomerGuid,
                    session.CustomerId,
                    session.CompanyId,
                    session.UserId,
                    replacement.LoginName,
                    replacement.ExpiresAtUtc,
                    session.SessionExpiresAt
                }, cancellationToken: ct));

            await CreatePrincipalAsync(replacement, access, ct);

            await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            var revoked = await connection.ExecuteAsync(new CommandDefinition("""
                UPDATE [central].[MobileCredentialSessions]
                SET RevokedAt = SYSUTCDATETIME(), LastRefreshedAt = SYSUTCDATETIME()
                WHERE SessionId = @SessionId AND ActivatedAt IS NOT NULL
                  AND RevokedAt IS NULL AND SessionExpiresAt > SYSUTCDATETIME();
                """, new { session.SessionId }, transaction, cancellationToken: ct));
            var activated = await connection.ExecuteAsync(new CommandDefinition("""
                UPDATE [central].[MobileCredentialSessions]
                SET ActivatedAt = SYSUTCDATETIME()
                WHERE SessionId = @ReplacementSessionId
                  AND SessionFamilyId = @SessionFamilyId
                  AND ActivatedAt IS NULL AND RevokedAt IS NULL;
                """, new
                {
                    ReplacementSessionId = replacementSessionId.Value,
                    session.SessionFamilyId
                }, transaction, cancellationToken: ct));
            if (revoked != 1 || activated != 1)
            {
                await transaction.RollbackAsync(ct);
                await BestEffortMarkRevokedAsync(replacementSessionId.Value);
                await BestEffortRevokePrincipalAsync(replacement.LoginName);
                return BrokerResult.Rejected("invalid_token", "نشست اتصال دیگر فعال نیست.");
            }
            await transaction.CommitAsync(ct);

            await BestEffortRevokePrincipalAsync(session.SqlLoginName);
            var user = new BrokerUser
            {
                UserId = session.UserId,
                Username = session.Username,
                DisplayName = session.DisplayName,
                Role = session.Role,
                RoleId = session.RoleId,
                RoleTitle = session.RoleTitle,
                IsActive = session.UserIsActive
            };
            return BrokerResult.Success(CreateResponse(user, session.CustomerGuid, newToken,
                session.SessionExpiresAt, replacement));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            if (replacementSessionId is not null)
                await BestEffortMarkRevokedAsync(replacementSessionId.Value);
            if (replacement is not null)
                await BestEffortRevokePrincipalAsync(replacement.LoginName);
            throw;
        }
        catch (Exception ex)
        {
            if (replacementSessionId is not null)
                await BestEffortMarkRevokedAsync(replacementSessionId.Value);
            if (replacement is not null)
                await BestEffortRevokePrincipalAsync(replacement.LoginName);
            LogSafeFailure("refresh", ex);
            return InfrastructureFailure(ex);
        }
    }

    public async Task RevokeAsync(string bearerToken, CancellationToken ct)
    {
        if (!_isAvailable || string.IsNullOrWhiteSpace(bearerToken))
            return;

        // Once accepted, revocation gets a short server-owned completion window
        // even if the HTTP client disconnects. Expiry cleanup remains the
        // backstop if SQL is unavailable for the whole window.
        using var revocation = new CancellationTokenSource(_cleanupTimeout);
        var revokeCt = revocation.Token;
        await using var connection = await OpenIssuerConnectionAsync(revokeCt);
        var familyId = await FindSessionFamilyAsync(connection, Sha256(bearerToken), revokeCt);
        if (familyId is null)
            return;

        // Prefer the same lineage lock as refresh to avoid row-lock deadlocks,
        // but never make revocation conditional on acquiring it. If the lock
        // times out, the family update still marks a pending successor or makes
        // refresh's compare-and-swap fail. If refresh commits first, the update
        // waits on row locks and then catches the activated successor.
        _ = await AcquireFamilyLockAsync(connection, familyId.Value, revokeCt);
        var principals = await MarkFamilyRevokedAsync(connection, familyId.Value, revokeCt);
        await BestEffortRevokePrincipalsAsync(principals);
    }

    public async Task CleanupExpiredAsync(CancellationToken ct)
    {
        if (!_isAvailable)
            return;

        await using var connection = await OpenIssuerConnectionAsync(ct);
        var expired = (await connection.QueryAsync<(Guid SessionId, string SqlLoginName)>(
            new CommandDefinition("""
                SELECT SessionId, SqlLoginName
                FROM [central].[MobileCredentialSessions] s
                WHERE s.RevokedAt IS NOT NULL
                   OR (s.ActivatedAt IS NULL AND s.CreatedAt < DATEADD(MINUTE, -2, SYSUTCDATETIME()))
                   OR s.CredentialExpiresAt <= SYSUTCDATETIME()
                   OR s.SessionExpiresAt <= SYSUTCDATETIME()
                   OR NOT EXISTS
                      (
                          SELECT 1
                          FROM [central].[CredentialCustomers] c
                          JOIN [central].[Companies] co ON co.CompanyId = c.CompanyId
                          JOIN [central].[Users] u ON u.UserId = s.UserId
                          WHERE c.CredentialCustomerId = s.CustomerId
                            AND c.CustomerGuid = s.CustomerGuid
                            AND c.CompanyId = s.CompanyId
                            AND c.IsActive = 1
                            AND c.CredentialAccessEnabled = 1
                            AND co.IsActive = 1 AND co.IsDeleted = 0
                            AND u.IsActive = 1 AND u.IsDeleted = 0
                            AND
                            (
                                u.Role = N'Admin'
                                OR EXISTS
                                   (SELECT 1 FROM [central].[UserCompanies] uc
                                    WHERE uc.UserId = s.UserId AND uc.CompanyId = s.CompanyId)
                            )
                      );
                """, cancellationToken: ct))).AsList();

        foreach (var session in expired)
        {
            await MarkRevokedAsync(connection, session.SessionId, ct);
            await BestEffortRevokePrincipalAsync(session.SqlLoginName);
        }

        await connection.ExecuteAsync(new CommandDefinition("""
            DELETE FROM [central].[CredentialRequestNonces] WHERE ExpiresAt <= SYSUTCDATETIME();
            DELETE FROM [central].[MobileCredentialSessions]
            WHERE RevokedAt < DATEADD(DAY, -7, SYSUTCDATETIME())
              AND SUSER_ID(SqlLoginName) IS NULL
              AND DATABASE_PRINCIPAL_ID(SqlLoginName) IS NULL;
            """, cancellationToken: ct));
    }

    // ────────────────────────────────────────────────────────────────
    // Encrypted master connection-string delivery (appsettings.json → API → MAUI)
    // ────────────────────────────────────────────────────────────────
    // Reads the issuer connection string from appsettings.json (supports
    // ENC: encrypted-at-rest via TarazinConnection) and re-encrypts it
    // per-session with a key derived from the bearer token (SHA-256 of the
    // token). MAUI derives the same key from its stored plaintext token and
    // decrypts in memory — no static secret is stored in the MAUI binary
    // for this path. The outer HTTPS (TLS) remains the primary transport
    // protection; the inner AES layer satisfies the "encrypted to MAUI"
    // requirement without putting a long-term decryption key in the client.

    public async Task<BrokerEncryptedResult> GetEncryptedConnectionAsync(
        EncryptedConnectionRequest request,
        string bearerToken,
        CancellationToken ct)
    {
        if (!_isAvailable)
            return BrokerEncryptedResult.Unavailable(_unavailabilityCode);

        try
        {
            return await GetEncryptedConnectionCoreAsync(request, bearerToken, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            LogSafeFailure("encrypted-connection", ex);
            return BrokerEncryptedResult.Failure(InfrastructureFailure(ex).Error!);
        }
    }

    private async Task<BrokerEncryptedResult> GetEncryptedConnectionCoreAsync(
        EncryptedConnectionRequest request,
        string bearerToken,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(bearerToken) ||
            !IsValidRequest(request.CustomerGuid, request.Nonce, request.TimestampUtc))
            return BrokerEncryptedResult.Rejected("invalid_request", "درخواست اتصال معتبر نیست.");

        await using var connection = await OpenIssuerConnectionAsync(ct);
        if (!await ConsumeNonceAsync(connection, request.Nonce, ct))
            return BrokerEncryptedResult.Rejected("replayed_request", "این درخواست قبلاً استفاده شده است.");

        var tokenHash = Sha256(bearerToken);
        var familyId = await FindSessionFamilyAsync(connection, tokenHash, ct);
        if (familyId is null)
            return BrokerEncryptedResult.Rejected("invalid_token", "نشست اتصال معتبر یا فعال نیست.");

        var session = await LoadSessionAsync(connection, tokenHash, ct);
        if (session is null)
        {
            var principals = await MarkFamilyRevokedAsync(connection, familyId.Value, ct);
            await BestEffortRevokePrincipalsAsync(principals);
            return BrokerEncryptedResult.Rejected("invalid_token", "نشست اتصال معتبر یا فعال نیست.");
        }

        var now = DateTimeOffset.UtcNow;
        if (session.ActivatedAt is null || session.RevokedAt is not null ||
            session.SessionExpiresAt <= now || session.CustomerGuid != request.CustomerGuid)
            return BrokerEncryptedResult.Rejected("invalid_token", "نشست اتصال معتبر یا فعال نیست.");

        if (!session.UserIsActive || !session.CustomerIsActive || session.CustomerIsDeleted ||
            !session.CredentialAccessEnabled || !session.CompanyIsActive ||
            session.CompanyIsDeleted || !session.IsAuthorized)
        {
            var principals = await MarkFamilyRevokedAsync(connection, session.SessionFamilyId, ct);
            await BestEffortRevokePrincipalsAsync(principals);
            return BrokerEncryptedResult.Rejected("authorization_expired", "مجوز مشتری یا کاربر منقضی شده است.");
        }

        // Authenticated and authorized — encrypt the issuer connection string
        // with a per-session key derived from the bearer token.
        // Also extend the encrypted payload lifetime to match the current
        // credential lifetime so MAUI can use it until the next refresh.
        var issuerPayload = _issuerConnectionString;
        if (string.IsNullOrWhiteSpace(issuerPayload))
            return BrokerEncryptedResult.Failure(new CredentialBrokerError { Code = "service_unavailable", Message = "سرویس اتصال موقتاً در دسترس نیست." });

        var perSessionKey = ConnectionStringProtector.DeriveKeyFromToken(bearerToken);
        var encrypted = ConnectionStringProtector.EncryptWithKeyBytes(issuerPayload, perSessionKey);

        // Zero the per-session key bytes as soon as used (best-effort).
        CryptographicOperations.ZeroMemory(perSessionKey);

        var response = new EncryptedConnectionResponse
        {
            EncryptedConnectionString = encrypted,
            ExpiresAtUtc = DateTimeOffset.UtcNow.Add(_credentialLifetime),
            Database = _database
        };

        return BrokerEncryptedResult.Success(response);
    }

    private IssuedPrincipal PlanPrincipal()
        => new(
            "tz_m_" + Guid.NewGuid().ToString("N"),
            CreateSqlPassword(),
            DateTimeOffset.UtcNow.Add(_credentialLifetime));

    private async Task<SqlAccessProfile> LoadAccessProfileAsync(
        SqlConnection connection,
        int roleId,
        string role,
        CancellationToken ct)
    {
        if (string.Equals(role, TarazinRoles.Admin, StringComparison.OrdinalIgnoreCase))
            return new SqlAccessProfile(RuntimeSchemas, RuntimeSchemas, [], []);

        var keys = (await connection.QueryAsync<string>(new CommandDefinition("""
            SELECT p.PermissionKey
            FROM [central].[RolePermissions] rp
            JOIN [central].[Permissions] p ON p.PermissionId = rp.PermissionId
            WHERE rp.RoleId = @RoleId AND p.IsDeleted = 0;
            """, new { RoleId = roleId }, cancellationToken: ct))).AsList();

        var readable = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var writable = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var objectReads = new HashSet<SqlObjectGrant>();
        var objectWrites = new HashSet<SqlObjectGrant>();

        static void AddCentralReads(HashSet<SqlObjectGrant> grants)
        {
            foreach (var table in new[] { "News", "BlogPosts", "GalleryItems", "Parties", "Companies", "FiscalYears" })
                grants.Add(new SqlObjectGrant("central", table, "SELECT"));
        }

        static void AddCentralWrites(HashSet<SqlObjectGrant> grants)
        {
            foreach (var table in new[] { "News", "BlogPosts", "GalleryItems", "Parties" })
                grants.Add(new SqlObjectGrant("central", table, "INSERT, UPDATE, DELETE"));
        }

        foreach (var permission in keys)
        {
            if (permission == TarazinPermissions.SystemAdmin)
            {
                readable.UnionWith(RuntimeSchemas);
                writable.UnionWith(RuntimeSchemas);
                continue;
            }

            if (permission == TarazinPermissions.Audit)
            {
                objectReads.Add(new SqlObjectGrant("central", "AuditLog", "SELECT"));
                continue;
            }

            if (permission == TarazinPermissions.Users)
            {
                // Named user workflows only: no central-schema mutation and no
                // read access to PasswordHash (the runtime role hard-denies it).
                objectWrites.Add(new SqlObjectGrant("central", "Users", "INSERT, UPDATE"));
                objectWrites.Add(new SqlObjectGrant("central", "UserCompanies", "INSERT"));
                continue;
            }

            if (permission == TarazinPermissions.Roles)
            {
                // Named role workflows need role upsert plus junction replace;
                // they do not need arbitrary mutation of other central tables.
                objectWrites.Add(new SqlObjectGrant("central", "Roles", "INSERT, UPDATE"));
                objectWrites.Add(new SqlObjectGrant("central", "RolePermissions", "INSERT, DELETE"));
                continue;
            }

            if (permission.StartsWith("rates.", StringComparison.OrdinalIgnoreCase))
            {
                readable.Add("currency");
                if (AllowsMutation(permission))
                    writable.Add("currency");
                continue;
            }

            var definition = TarazinPermissions.All.FirstOrDefault(p =>
                string.Equals(p.Key, permission, StringComparison.OrdinalIgnoreCase));
            if (definition is null || !RuntimeSchemas.Contains(definition.ModuleKey, StringComparer.OrdinalIgnoreCase))
                continue;

            if (string.Equals(definition.ModuleKey, "central", StringComparison.OrdinalIgnoreCase))
            {
                AddCentralReads(objectReads);
                if (AllowsMutation(permission))
                    AddCentralWrites(objectWrites);
                continue;
            }

            readable.Add(definition.ModuleKey);
            if (AllowsMutation(permission))
                writable.Add(definition.ModuleKey);
        }

        return new SqlAccessProfile(
            readable.ToArray(), writable.ToArray(), objectReads.ToArray(), objectWrites.ToArray());
    }

    private static bool AllowsMutation(string permission)
    {
        if (permission.EndsWith(".entry", StringComparison.OrdinalIgnoreCase) ||
            permission.EndsWith(".special", StringComparison.OrdinalIgnoreCase) ||
            permission.EndsWith(".settings", StringComparison.OrdinalIgnoreCase) ||
            permission.EndsWith(".admin", StringComparison.OrdinalIgnoreCase))
            return true;

        return permission is
            TarazinPermissions.RateFetch or TarazinPermissions.RateChange or
            TarazinPermissions.RateOverride or TarazinPermissions.RateChangeBuy or
            TarazinPermissions.RateChangeSell or TarazinPermissions.RateChangeGold or
            TarazinPermissions.RateChangeCurrency or TarazinPermissions.RateConfirm or
            TarazinPermissions.ChartCreate or TarazinPermissions.ChartEdit or
            TarazinPermissions.ChartDelete or TarazinPermissions.ChartMove or
            TarazinPermissions.ChartReorder or TarazinPermissions.ChartManageDetil or
            TarazinPermissions.DocumentEdit or TarazinPermissions.DocumentDelete or
            TarazinPermissions.DocumentDraft or TarazinPermissions.DocumentConfirm or
            TarazinPermissions.DocumentFinalize or TarazinPermissions.DocumentRevert;
    }

    private async Task CreatePrincipalAsync(
        IssuedPrincipal principal,
        SqlAccessProfile access,
        CancellationToken ct)
    {
        var quotedLogin = QuoteIdentifier(principal.LoginName);
        var quotedDatabase = QuoteIdentifier(_database);
        var role = QuoteIdentifier("tarazin_maui_runtime");

        await using var master = new SqlConnection(TarazinConnection.ToMaster(_issuerConnectionString));
        await master.OpenAsync(ct);
        var escapedPassword = principal.Password.Replace("'", "''", StringComparison.Ordinal);
        await master.ExecuteAsync(new CommandDefinition($"""
            CREATE LOGIN {quotedLogin}
            WITH PASSWORD = N'{escapedPassword}', CHECK_POLICY = ON,
                 CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = {quotedDatabase};
            DENY VIEW ANY DATABASE TO {quotedLogin};
            DENY VIEW SERVER STATE TO {quotedLogin};
            DENY ALTER ANY LOGIN TO {quotedLogin};
            DENY ALTER ANY SERVER ROLE TO {quotedLogin};
            """, cancellationToken: ct));

        try
        {
            await using var database = await OpenIssuerConnectionAsync(ct);
            var revokeSharedGrants = string.Join(Environment.NewLine,
                RuntimeSchemas.Select(schema =>
                    $"REVOKE SELECT, INSERT, UPDATE, DELETE ON SCHEMA::{QuoteIdentifier(schema)} FROM {role};"));
            var readGrants = string.Join(Environment.NewLine,
                access.ReadSchemas.Select(schema =>
                    $"GRANT SELECT ON SCHEMA::{QuoteIdentifier(schema)} TO {quotedLogin};"));
            var writeGrants = string.Join(Environment.NewLine,
                access.WriteSchemas.Select(schema =>
                    $"GRANT INSERT, UPDATE, DELETE ON SCHEMA::{QuoteIdentifier(schema)} TO {quotedLogin};"));
            var objectReadGrants = string.Join(Environment.NewLine,
                access.ObjectReads.Select(grant =>
                    $"GRANT {grant.Actions} ON OBJECT::{QuoteIdentifier(grant.Schema)}.{QuoteIdentifier(grant.Object)} TO {quotedLogin};"));
            var objectWriteGrants = string.Join(Environment.NewLine,
                access.ObjectWrites.Select(grant =>
                    $"GRANT {grant.Actions} ON OBJECT::{QuoteIdentifier(grant.Schema)}.{QuoteIdentifier(grant.Object)} TO {quotedLogin};"));
            var sql = $"""
                DECLARE @RoleLockResult INT;
                EXEC @RoleLockResult = sys.sp_getapplock
                    @Resource = N'tarazin_maui_runtime_role',
                    @LockMode = N'Exclusive', @LockOwner = N'Session', @LockTimeout = 10000;
                IF @RoleLockResult < 0
                    THROW 51090, N'Runtime role lock could not be acquired.', 1;

                IF DATABASE_PRINCIPAL_ID(N'tarazin_maui_runtime') IS NULL
                    CREATE ROLE {role};
                {revokeSharedGrants}
                DENY ALTER ANY USER TO {role};
                DENY VIEW DEFINITION TO {role};
                DENY VIEW DATABASE STATE TO {role};

                -- Normalize legacy role-level decisions before applying the
                -- current control-plane denies and login/context baseline.
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[Sessions] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[CredentialCustomers] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[MobileCredentialSessions] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[CredentialRequestNonces] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[Users] FROM {role};
                REVOKE SELECT ON OBJECT::[central].[Users] ([PasswordHash]) FROM {role};
                REVOKE UPDATE ON OBJECT::[central].[Users] ([PasswordHash]) FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[Companies] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[FiscalYears] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[UserCompanies] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[UserFiscalYears] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[UserActiveContext] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[Roles] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[Permissions] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[RolePermissions] FROM {role};
                REVOKE SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[AuditLog] FROM {role};

                DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[Sessions] TO {role};
                DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[CredentialCustomers] TO {role};
                DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[MobileCredentialSessions] TO {role};
                DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::[central].[CredentialRequestNonces] TO {role};

                GRANT SELECT ON OBJECT::[central].[Users] TO {role};
                DENY SELECT ON OBJECT::[central].[Users] ([PasswordHash]) TO {role};
                GRANT SELECT ON OBJECT::[central].[Roles] TO {role};
                GRANT SELECT ON OBJECT::[central].[Permissions] TO {role};
                GRANT SELECT ON OBJECT::[central].[RolePermissions] TO {role};
                GRANT SELECT ON OBJECT::[central].[Companies] TO {role};
                GRANT SELECT ON OBJECT::[central].[FiscalYears] TO {role};
                GRANT SELECT ON OBJECT::[central].[UserCompanies] TO {role};
                GRANT SELECT ON OBJECT::[central].[UserFiscalYears] TO {role};
                GRANT SELECT, INSERT, UPDATE ON OBJECT::[central].[UserActiveContext] TO {role};

                -- Existing post-login context preparation creates the current
                -- fiscal year when absent. Company-bound RLS constrains it.
                GRANT INSERT, UPDATE ON OBJECT::[central].[FiscalYears] TO {role};
                GRANT INSERT ON OBJECT::[central].[UserFiscalYears] TO {role};

                -- Audit writes remain append-only for generated principals.
                GRANT INSERT ON OBJECT::[central].[AuditLog] TO {role};
                DENY UPDATE, DELETE ON OBJECT::[central].[AuditLog] TO {role};
                CREATE USER {quotedLogin} FOR LOGIN {quotedLogin};
                ALTER ROLE {role} ADD MEMBER {quotedLogin};
                {readGrants}
                {writeGrants}
                {objectReadGrants}
                {objectWriteGrants}
                EXEC sys.sp_releaseapplock @Resource = N'tarazin_maui_runtime_role', @LockOwner = N'Session';
                """;
            await database.ExecuteAsync(new CommandDefinition(sql, cancellationToken: ct));
        }
        catch
        {
            await BestEffortRevokePrincipalAsync(principal.LoginName);
            throw;
        }
    }

    private static async Task<Guid?> FindSessionFamilyAsync(
        SqlConnection connection,
        string tokenHash,
        CancellationToken ct)
    {
        return await connection.QueryFirstOrDefaultAsync<Guid?>(new CommandDefinition("""
            SELECT SessionFamilyId
            FROM [central].[MobileCredentialSessions]
            WHERE TokenHash = @TokenHash;
            """, new { TokenHash = tokenHash }, cancellationToken: ct));
    }

    private static async Task<bool> AcquireFamilyLockAsync(
        SqlConnection connection,
        Guid familyId,
        CancellationToken ct)
    {
        var result = await connection.QuerySingleAsync<int>(new CommandDefinition("""
            DECLARE @Result INT;
            EXEC @Result = sys.sp_getapplock
                @Resource = @Resource,
                @LockMode = N'Exclusive',
                @LockOwner = N'Session',
                @LockTimeout = 10000;
            SELECT @Result;
            """, new { Resource = "tarazin_mobile_family:" + familyId.ToString("N") },
            cancellationToken: ct));
        return result >= 0;
    }

    private static async Task<BrokerSession?> LoadSessionAsync(
        SqlConnection connection,
        string tokenHash,
        CancellationToken ct)
    {
        return await connection.QueryFirstOrDefaultAsync<BrokerSession>(new CommandDefinition("""
            SELECT s.SessionId, s.SessionFamilyId, s.ActivatedAt, s.CustomerGuid,
                   s.CustomerId, s.CompanyId, s.UserId, s.SqlLoginName,
                   s.SessionExpiresAt, s.RevokedAt,
                   u.Username, u.DisplayName, u.Role, u.RoleId, r.Title AS RoleTitle,
                   u.IsActive AS UserIsActive,
                   c.IsActive AS CustomerIsActive, CAST(0 AS BIT) AS CustomerIsDeleted,
                   c.CredentialAccessEnabled,
                   co.IsActive AS CompanyIsActive, co.IsDeleted AS CompanyIsDeleted,
                   CAST(CASE WHEN u.Role = N'Admin' OR EXISTS (
                       SELECT 1 FROM [central].[UserCompanies] uc
                       WHERE uc.UserId = u.UserId AND uc.CompanyId = s.CompanyId)
                       THEN 1 ELSE 0 END AS BIT) AS IsAuthorized
            FROM [central].[MobileCredentialSessions] s
            JOIN [central].[Users] u ON u.UserId = s.UserId AND u.IsDeleted = 0
            LEFT JOIN [central].[Roles] r ON r.RoleId = u.RoleId AND r.IsDeleted = 0
            JOIN [central].[CredentialCustomers] c
              ON c.CredentialCustomerId = s.CustomerId AND c.CustomerGuid = s.CustomerGuid
             AND c.CompanyId = s.CompanyId
            JOIN [central].[Companies] co ON co.CompanyId = s.CompanyId
            WHERE s.TokenHash = @TokenHash;
            """, new { TokenHash = tokenHash }, cancellationToken: ct));
    }

    private static async Task<IReadOnlyList<string>> MarkFamilyRevokedAsync(
        SqlConnection connection,
        Guid familyId,
        CancellationToken ct)
    {
        await connection.ExecuteAsync(new CommandDefinition("""
            UPDATE [central].[MobileCredentialSessions]
            SET RevokedAt = COALESCE(RevokedAt, SYSUTCDATETIME())
            WHERE SessionFamilyId = @SessionFamilyId;
            """, new { SessionFamilyId = familyId }, cancellationToken: ct));

        return (await connection.QueryAsync<string>(new CommandDefinition("""
            SELECT SqlLoginName
            FROM [central].[MobileCredentialSessions]
            WHERE SessionFamilyId = @SessionFamilyId;
            """, new { SessionFamilyId = familyId }, cancellationToken: ct))).AsList();
    }

    private async Task BestEffortRevokePrincipalsAsync(IEnumerable<string> loginNames)
    {
        foreach (var loginName in loginNames.Distinct(StringComparer.Ordinal))
            await BestEffortRevokePrincipalAsync(loginName);
    }

    private async Task BestEffortMarkRevokedAsync(Guid sessionId)
    {
        using var cleanup = new CancellationTokenSource(_cleanupTimeout);
        try
        {
            await using var connection = await OpenIssuerConnectionAsync(cleanup.Token);
            await MarkRevokedAsync(connection, sessionId, cleanup.Token);
        }
        catch (Exception ex)
        {
            LogSafeFailure("mark-revoked", ex);
        }
    }

    private async Task BestEffortRevokePrincipalAsync(string loginName)
    {
        using var cleanup = new CancellationTokenSource(_cleanupTimeout);
        var ct = cleanup.Token;
        try
        {
            if (!IsGeneratedLoginName(loginName))
                return;

            await using var master = new SqlConnection(TarazinConnection.ToMaster(_issuerConnectionString));
            await master.OpenAsync(ct);
            var quoted = QuoteIdentifier(loginName);

            // Disable first to close the race where a new pooled/direct session
            // could connect after KILL enumeration but before DROP LOGIN.
            await master.ExecuteAsync(new CommandDefinition(
                $"IF SUSER_ID(N'{loginName}') IS NOT NULL ALTER LOGIN {quoted} DISABLE;",
                cancellationToken: ct));
            await master.ExecuteAsync(new CommandDefinition("""
                DECLARE @kill NVARCHAR(MAX) = N'';
                SELECT @kill = @kill + N'KILL ' + CONVERT(NVARCHAR(12), session_id) + N';'
                FROM sys.dm_exec_sessions
                WHERE original_login_name = @LoginName AND session_id <> @@SPID;
                IF LEN(@kill) > 0 EXEC(@kill);
                """, new { LoginName = loginName }, cancellationToken: ct));

            await using var database = await OpenIssuerConnectionAsync(ct);
            await database.ExecuteAsync(new CommandDefinition(
                $"IF DATABASE_PRINCIPAL_ID(N'{loginName}') IS NOT NULL DROP USER {quoted};",
                cancellationToken: ct));
            await master.ExecuteAsync(new CommandDefinition(
                $"IF SUSER_ID(N'{loginName}') IS NOT NULL DROP LOGIN {quoted};",
                cancellationToken: ct));
        }
        catch (Exception ex)
        {
            LogSafeFailure("revoke", ex);
        }
    }

    private async Task<bool> ConsumeNonceAsync(SqlConnection connection, string nonce, CancellationToken ct)
    {
        try
        {
            await connection.ExecuteAsync(new CommandDefinition("""
                INSERT INTO [central].[CredentialRequestNonces] (NonceHash, ExpiresAt)
                VALUES (@NonceHash, DATEADD(SECOND, @LifetimeSeconds, SYSUTCDATETIME()));
                """, new { NonceHash = Sha256(nonce), LifetimeSeconds = (int)(_requestSkew.TotalSeconds * 2) },
                cancellationToken: ct));
            return true;
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            return false;
        }
    }

    private async Task<SqlConnection> OpenIssuerConnectionAsync(CancellationToken ct)
    {
        var connection = new SqlConnection(_issuerConnectionString);
        try
        {
            await connection.OpenAsync(ct);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    private static async Task MarkRevokedAsync(SqlConnection connection, Guid sessionId, CancellationToken ct)
    {
        await connection.ExecuteAsync(new CommandDefinition("""
            UPDATE [central].[MobileCredentialSessions]
            SET RevokedAt = COALESCE(RevokedAt, SYSUTCDATETIME())
            WHERE SessionId = @SessionId;
            """, new { SessionId = sessionId }, cancellationToken: ct));
    }

    private MobileConnectionResponse CreateResponse(
        BrokerUser user,
        Guid customerGuid,
        string token,
        DateTimeOffset sessionExpires,
        IssuedPrincipal principal)
    {
        var response = new MobileConnectionResponse
        {
            User = new UserRow
            {
                UserId = user.UserId,
                Username = user.Username,
                PasswordHash = "",
                DisplayName = user.DisplayName,
                Role = user.Role,
                RoleId = user.RoleId,
                RoleTitle = user.RoleTitle,
                IsActive = user.IsActive
            },
            CustomerGuid = customerGuid,
            SessionToken = token,
            SessionExpiresAtUtc = sessionExpires,
            Credential = new MobileSqlCredential
            {
                Server = _publicServer,
                Database = _database,
                Username = principal.LoginName,
                Password = principal.Password,
                ExpiresAtUtc = principal.ExpiresAtUtc,
                Encrypt = true,
                TrustServerCertificate = false
            }
        };

        // SQL certificate validation stays enabled in every environment. Local
        // development needs a locally trusted SQL certificate, not a client-side
        // validation bypass embedded in the credential response.
        return response;
    }

    private bool IsValidRequest(Guid customerGuid, string nonce, DateTimeOffset timestamp)
    {
        if (customerGuid == Guid.Empty || string.IsNullOrWhiteSpace(nonce) || nonce.Length is < 22 or > 128)
            return false;

        // Range comparisons avoid overflow for adversarial DateTimeOffset values.
        var now = DateTimeOffset.UtcNow;
        return timestamp >= now.Subtract(_requestSkew) && timestamp <= now.Add(_requestSkew);
    }

    private static string GetBearerToken(HttpRequest request)
    {
        var header = request.Headers.Authorization.ToString();
        const string prefix = "Bearer ";
        if (!header.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            return "";

        var token = header[prefix.Length..].Trim();
        return token.Length is >= 32 and <= 256 ? token : "";
    }

    public static string ReadBearerToken(HttpRequest request) => GetBearerToken(request);

    private static BrokerResult InfrastructureFailure(Exception ex)
    {
        if (IsIssuerPermissionFailure(ex))
            return BrokerResult.IssuerNotAuthorized();
        if (IsBrokerSchemaFailure(ex))
            return BrokerResult.NotReady();
        return BrokerResult.Unavailable();
    }

    private static bool IsIssuerPermissionFailure(Exception ex)
    {
        var sql = FindSqlException(ex);
        // 229: object permission denied; 15151/15247: principal/login
        // administration denied. All mean the server-side issuer cannot create,
        // grant, revoke, or clean up the short-lived MAUI principal.
        return sql?.Number is 229 or 15151 or 15247;
    }

    private static bool IsBrokerSchemaFailure(Exception ex)
    {
        var sql = FindSqlException(ex);
        // 207/208 signal a missing broker control-plane column/table, normally
        // because the Web startup migration did not complete.
        return sql?.Number is 207 or 208;
    }

    private static SqlException? FindSqlException(Exception? exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is SqlException sql)
                return sql;
        }
        return null;
    }

    private void LogSafeFailure(string operation, Exception ex)
    {
        var sqlNumber = FindSqlException(ex)?.Number ?? 0;
        _logger.LogError("Credential broker {Operation} failed ({ErrorType}, SqlNumber={SqlNumber})",
            operation, ex.GetType().Name, sqlNumber);
    }

    private static string CreateOpaqueSecret(int byteCount)
        => Base64Url(RandomNumberGenerator.GetBytes(byteCount));

    private static string CreateSqlPassword()
        => "Tz!" + Base64Url(RandomNumberGenerator.GetBytes(36)) + "9a";

    private static string Base64Url(byte[] bytes)
        => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string Sha256(string value)
        => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private static string QuoteIdentifier(string identifier)
        => "[" + identifier.Replace("]", "]]", StringComparison.Ordinal) + "]";

    private static bool IsGeneratedLoginName(string loginName)
        => loginName.Length == 37 && loginName.StartsWith("tz_m_", StringComparison.Ordinal) &&
           Guid.TryParseExact(loginName[5..], "N", out _);

    private static string ValidatePublicServer(string value)
    {
        var server = value.Trim();
        if (server.Length is < 1 or > 512 || server.IndexOfAny([';', '=', '\r', '\n', '\0']) >= 0)
            throw new InvalidOperationException("CredentialBroker:PublicSqlServer is not a valid SQL server endpoint.");
        return server;
    }

    private static int Clamp(IConfiguration config, string key, int fallback, int minimum, int maximum)
        => int.TryParse(config[key], out var value) ? Math.Clamp(value, minimum, maximum) : fallback;

    private sealed class BrokerUser
    {
        public int UserId { get; init; }
        public string Username { get; init; } = "";
        public string PasswordHash { get; init; } = "";
        public string DisplayName { get; init; } = "";
        public string Role { get; init; } = "";
        public int RoleId { get; init; }
        public string RoleTitle { get; init; } = "";
        public bool IsActive { get; init; }
    }

    private sealed class BrokerCustomer
    {
        public int CustomerId { get; init; }
        public Guid CustomerGuid { get; init; }
        public int CompanyId { get; init; }
        public bool IsActive { get; init; }
        public bool IsDeleted { get; init; }
        public bool CredentialAccessEnabled { get; init; }
        public bool CompanyIsActive { get; init; }
        public bool CompanyIsDeleted { get; init; }
        public bool IsAuthorized { get; init; }
    }

    private sealed class BrokerSession
    {
        public Guid SessionId { get; init; }
        public Guid SessionFamilyId { get; init; }
        public DateTimeOffset? ActivatedAt { get; init; }
        public Guid CustomerGuid { get; init; }
        public int CustomerId { get; init; }
        public int CompanyId { get; init; }
        public int UserId { get; init; }
        public string SqlLoginName { get; init; } = "";
        public DateTimeOffset SessionExpiresAt { get; init; }
        public DateTimeOffset? RevokedAt { get; init; }
        public string Username { get; init; } = "";
        public string DisplayName { get; init; } = "";
        public string Role { get; init; } = "";
        public int RoleId { get; init; }
        public string RoleTitle { get; init; } = "";
        public bool UserIsActive { get; init; }
        public bool CustomerIsActive { get; init; }
        public bool CustomerIsDeleted { get; init; }
        public bool CredentialAccessEnabled { get; init; }
        public bool CompanyIsActive { get; init; }
        public bool CompanyIsDeleted { get; init; }
        public bool IsAuthorized { get; init; }
    }

    private sealed record IssuedPrincipal(string LoginName, string Password, DateTimeOffset ExpiresAtUtc);
    private sealed record SqlObjectGrant(string Schema, string Object, string Actions);
    private sealed record SqlAccessProfile(
        IReadOnlyCollection<string> ReadSchemas,
        IReadOnlyCollection<string> WriteSchemas,
        IReadOnlyCollection<SqlObjectGrant> ObjectReads,
        IReadOnlyCollection<SqlObjectGrant> ObjectWrites);
}

public sealed record BrokerResult(int StatusCode, MobileConnectionResponse? Response, CredentialBrokerError? Error)
{
    public static BrokerResult Success(MobileConnectionResponse response) => new(StatusCodes.Status200OK, response, null);
    public static BrokerResult Rejected(string code, string message)
    {
        var status = code switch
        {
            "invalid_request" => StatusCodes.Status400BadRequest,
            "invalid_credentials" or "invalid_token" or "authorization_expired" => StatusCodes.Status401Unauthorized,
            "replayed_request" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status403Forbidden
        };
        return new(status, null, new CredentialBrokerError { Code = code, Message = message });
    }
    public static BrokerResult Unavailable(string? code = null)
        => string.Equals(code, "broker_not_configured", StringComparison.Ordinal)
            ? new(StatusCodes.Status503ServiceUnavailable, null,
                new CredentialBrokerError
                {
                    Code = "broker_not_configured",
                    Message = "سرویس ورود MAUI روی سرور پیکربندی نشده است."
                })
            : new(StatusCodes.Status503ServiceUnavailable, null,
                new CredentialBrokerError { Code = "service_unavailable", Message = "سرویس اتصال موقتاً در دسترس نیست." });

    public static BrokerResult IssuerNotAuthorized() =>
        new(StatusCodes.Status503ServiceUnavailable, null,
            new CredentialBrokerError
            {
                Code = "issuer_not_authorized",
                Message = "سرویس ورود MAUI مجوز صدور اتصال موقت را ندارد."
            });

    public static BrokerResult NotReady() =>
        new(StatusCodes.Status503ServiceUnavailable, null,
            new CredentialBrokerError
            {
                Code = "broker_not_ready",
                Message = "سرویس ورود MAUI روی سرور آماده نشده است."
            });
}

public sealed record BrokerEncryptedResult(int StatusCode, EncryptedConnectionResponse? Response, CredentialBrokerError? Error)
{
    public static BrokerEncryptedResult Success(EncryptedConnectionResponse response) => new(StatusCodes.Status200OK, response, null);
    public static BrokerEncryptedResult Rejected(string code, string message)
    {
        var status = code switch
        {
            "invalid_request" => StatusCodes.Status400BadRequest,
            "invalid_token" or "authorization_expired" => StatusCodes.Status401Unauthorized,
            "replayed_request" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status403Forbidden
        };
        return new(status, null, new CredentialBrokerError { Code = code, Message = message });
    }
    public static BrokerEncryptedResult Unavailable(string? code = null)
        => string.Equals(code, "broker_not_configured", StringComparison.Ordinal)
            ? new(StatusCodes.Status503ServiceUnavailable, null,
                new CredentialBrokerError { Code = "broker_not_configured", Message = "سرویس ورود MAUI روی سرور پیکربندی نشده است." })
            : new(StatusCodes.Status503ServiceUnavailable, null,
                new CredentialBrokerError { Code = "service_unavailable", Message = "سرویس اتصال موقتاً در دسترس نیست." });

    public static BrokerEncryptedResult Failure(CredentialBrokerError error)
        => new(error.Code == "issuer_not_authorized" || error.Code == "broker_not_ready"
            ? StatusCodes.Status503ServiceUnavailable
            : StatusCodes.Status503ServiceUnavailable, null, error);
}
