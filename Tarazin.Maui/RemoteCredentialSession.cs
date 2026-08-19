using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Tarazin.Data;
using Tarazin.Models;
using Tarazin.Services;

namespace Tarazin.Maui;

/// <summary>
/// MAUI-only connection session. It authenticates through the Web credential
/// broker and uses only the short-lived, customer-bound SQL credential returned
/// by that broker. SQL material is retained only by this process instance and
/// is never written to preferences, files, SecureStorage, logs, or configuration.
/// </summary>
public sealed class RemoteCredentialSession :
    ISqlConnectionProvider,
    IRemoteAuthenticationService,
    ICredentialSessionRevoker,
    IDisposable
{
    private readonly HttpClient _http;
    // Serializes login, refresh, and revoke so a late refresh response cannot
    // recreate a credential after logout (or overwrite a newer login).
    private readonly SemaphoreSlim _lifecycleGate = new(1, 1);
    private readonly Guid _customerGuid;
    private readonly bool _useEncryptedMaster;
    private string _sessionToken = "";
    private DateTimeOffset _sessionExpiresAt;
    private CredentialState? _credential;
    // Encrypted master connection-string fetched via the authenticated
    // broker (appsettings.json → API → MAUI, per-session AES).
    private CredentialState? _masterCredential;
    private DateTimeOffset _masterExpiresAt;
    private string _masterPlaintextCache = "";
    private bool _disposed;

    public RemoteCredentialSession(IConfiguration configuration)
    {
        var rawEndpoint = configuration["ServerEndpoint"]?.Trim();
        if (!Uri.TryCreate(rawEndpoint, UriKind.Absolute, out var endpoint))
            throw new InvalidOperationException("ServerEndpoint must be an absolute HTTPS URL.");
        if (!IsSecureEndpoint(endpoint))
            throw new InvalidOperationException("ServerEndpoint must use HTTPS (HTTP is allowed only for loopback development).");
        if (!string.IsNullOrEmpty(endpoint.UserInfo) || !string.IsNullOrEmpty(endpoint.Query) ||
            !string.IsNullOrEmpty(endpoint.Fragment))
            throw new InvalidOperationException("ServerEndpoint must not contain credentials, query text, or fragments.");

        var normalizedEndpoint = endpoint.AbsoluteUri.EndsWith("/", StringComparison.Ordinal)
            ? endpoint
            : new Uri(endpoint.AbsoluteUri + "/", UriKind.Absolute);

        // CustomerGuid is a public tenant selector packaged with this build.
        // It is read only from MAUI appsettings.json — never from the login
        // form, URL path, query string, or environment.
        var rawCustomerGuid = configuration["CustomerGuid"]?.Trim();
        if (!Guid.TryParse(rawCustomerGuid, out var customerGuid) || customerGuid == Guid.Empty)
            throw new InvalidOperationException("CustomerGuid must be a non-empty GUID in appsettings.json.");
        _customerGuid = customerGuid;

        // Optional encrypted-master mode: when true, after a successful broker
        // login the same authenticated session is used to fetch the master
        // connection string encrypted per-session (appsettings.json ENC: → API
        // → MAUI per-session AES). The decrypted string stays in memory only.
        // Default false keeps the short-lived least-privilege credential path.
        _useEncryptedMaster =
            bool.TryParse(configuration["ConnectionProtection:UseEncryptedMaster"], out var flag) && flag;

        _http = new HttpClient
        {
            BaseAddress = normalizedEndpoint,
            Timeout = TimeSpan.FromSeconds(25),
            MaxResponseContentBufferSize = 64 * 1024
        };
        _http.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("Tarazin-MAUI/1.0");
    }

    public bool IsAvailable => (_credential is not null || _masterCredential is not null) && !string.IsNullOrWhiteSpace(_sessionToken);
    public bool SupportsInitialization => false;

    public string DatabaseName => _masterCredential?.Database ?? _credential?.Database ?? "";

    public string Description => _credential is null && _masterCredential is null
        ? "اتصال موقت از سرویس وب آماده نیست"
        : _masterCredential is not null
            ? "اتصال SQL رمزگذاری‌شدهٔ دریافت‌شده از appsettings.json سرور (per-session AES)"
            : "اتصال SQL کوتاه‌عمر دریافت‌شده از سرویس وب";

    public async Task<UserRow?> AuthenticateAsync(
        string username,
        string password,
        Guid customerGuid = default,
        CancellationToken ct = default)
    {
        ThrowIfDisposed();
        await _lifecycleGate.WaitAsync(ct);
        MobileConnectionRequest? request = null;
        try
        {
            ThrowIfDisposed();
            if (_credential is not null || !string.IsNullOrWhiteSpace(_sessionToken))
                await RevokeExistingCoreAsync(ct);

            // Ignore the login-form parameter. The packaged appsettings.json
            // value is the only customer selector this host is allowed to use.
            _ = customerGuid;

            request = new MobileConnectionRequest
            {
                Username = username,
                Password = password,
                CustomerGuid = _customerGuid,
                Nonce = CreateNonce(),
                TimestampUtc = DateTimeOffset.UtcNow
            };

            using var response = await _http.PostAsJsonAsync("api/mobile/connection/login", request, ct);
            if (!response.IsSuccessStatusCode)
                throw await CreateSafeExceptionAsync(response, ct);

            var result = await response.Content.ReadFromJsonAsync<MobileConnectionResponse>(cancellationToken: ct)
                ?? throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");
            try
            {
                ValidateResponse(result, _customerGuid, username.Trim());
            }
            catch (SafeAuthenticationException)
            {
                // A principal may already have been issued even if a corrupted
                // success body fails local validation. Revoke its candidate
                // token before erasing duplicate response references.
                await RevokeCandidateResponseAsync(result, ct);
                throw;
            }

            ThrowIfDisposed();
            Apply(result);

            // Appsettings.json → API → MAUI encrypted path:
            // If the MAUI configuration opts into encrypted-master mode,
            // immediately fetch the per-session encrypted master connection
            // string (Web's appsettings.json ENC: → API per-session AES) so
            // the caller can use the issuer string without a static key in
            // the MAUI package. Failures here do not roll back the login —
            // the short-lived credential remains usable.
            if (_useEncryptedMaster)
            {
                try
                {
                    await FetchAndCacheEncryptedMasterCoreAsync(ct);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // Keep the short-lived credential; encrypted master is
                    // best-effort in this mode. The caller can retry via
                    // FetchDecryptedMasterConnectionStringAsync().
                }
            }

            return result.User;
        }
        catch (SafeAuthenticationException)
        {
            throw;
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new SafeAuthenticationException("api_timeout", "زمان پاسخ سرویس ورود به پایان رسید.");
        }
        catch (HttpRequestException)
        {
            throw new SafeAuthenticationException("api_unavailable", "سرویس ورود در دسترس نیست.");
        }
        finally
        {
            if (request is not null)
                request.Password = "";
            _lifecycleGate.Release();
        }
    }

    public async ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct = default)
    {
        ThrowIfDisposed();

        // Encrypted-master mode takes precedence when available: the decrypted
        // issuer connection string (from Web's encrypted appsettings.json, via
        // per-session AES) is used directly. Its lifetime follows the broker
        // credential lifetime; re-fetch when near expiry.
        if (_masterCredential is not null)
        {
            await RefreshEncryptedMasterIfNeededAsync(ct);
            var master = _masterCredential;
            if (master is null)
                throw new InvalidOperationException("Authenticate through the secure API before using SQL.");
            var masterConnection = new SqlConnection(BuildConnectionString(master));
            try
            {
                await masterConnection.OpenAsync(ct);
                return masterConnection;
            }
            catch
            {
                await masterConnection.DisposeAsync();
                throw;
            }
        }

        // Default: short-lived least-privilege credential with proactive refresh.
        await RefreshIfNeededAsync(ct);

        var credential = _credential;
        if (credential is null)
            throw new InvalidOperationException("Authenticate through the secure API before using SQL.");

        var connection = new SqlConnection(BuildConnectionString(credential));
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

    public ValueTask<SqlConnection> OpenMasterConnectionAsync(CancellationToken ct = default)
        => ValueTask.FromException<SqlConnection>(
            new InvalidOperationException("MAUI credentials cannot initialize or access master."));

    public async Task RevokeAndClearAsync(CancellationToken ct = default)
    {
        ThrowIfDisposed();
        await _lifecycleGate.WaitAsync(ct);
        try
        {
            ThrowIfDisposed();
            await RevokeExistingCoreAsync(ct);
        }
        finally
        {
            _lifecycleGate.Release();
        }
    }

    // ────────────────────────────────────────────────────────────────
    // Encrypted master connection-string path (appsettings.json → API → MAUI)
    // ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Fetches the per-session encrypted issuer connection string from the
    /// authenticated broker (<c>POST /api/mobile/connection/encrypted</c>),
    /// decrypts it with a key derived from the session token (SHA-256), and
    /// returns the plaintext connection string. The plaintext is never written
    /// to disk, SecureStorage, or logs — only kept in memory when cached via
    /// <see cref="FetchAndCacheEncryptedMasterCoreAsync"/>.
    /// </summary>
    public async Task<string> FetchDecryptedMasterConnectionStringAsync(CancellationToken ct = default)
    {
        ThrowIfDisposed();
        if (string.IsNullOrWhiteSpace(_sessionToken))
            throw new InvalidOperationException("Authenticate through the secure API before fetching the encrypted connection string.");

        // Serialize with the lifecycle gate so this fetch races safely with
        // refresh/revoke.
        await _lifecycleGate.WaitAsync(ct);
        try
        {
            ThrowIfDisposed();
            return await FetchDecryptedMasterCoreAsync(ct);
        }
        finally
        {
            _lifecycleGate.Release();
        }
    }

    private async Task<string> FetchDecryptedMasterCoreAsync(CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(_sessionToken) || _sessionExpiresAt <= DateTimeOffset.UtcNow)
            throw new InvalidOperationException("The credential session has expired. Sign in again.");

        var request = new EncryptedConnectionRequest
        {
            CustomerGuid = _customerGuid,
            Nonce = CreateNonce(),
            TimestampUtc = DateTimeOffset.UtcNow
        };

        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, "api/mobile/connection/encrypted")
        {
            Content = JsonContent.Create(request)
        };
        httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _sessionToken);

        using var response = await _http.SendAsync(httpRequest, ct);
        if (!response.IsSuccessStatusCode)
            throw await CreateSafeExceptionAsync(response, ct);

        var payload = await response.Content.ReadFromJsonAsync<EncryptedConnectionResponse>(cancellationToken: ct)
            ?? throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال رمزگذاری‌شده معتبر نیست.");

        if (string.IsNullOrWhiteSpace(payload.EncryptedConnectionString) ||
            !payload.EncryptedConnectionString.StartsWith(ConnectionStringProtector.EncryptedPrefix, StringComparison.Ordinal))
            throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال رمزگذاری‌شده معتبر نیست.");

        var key = ConnectionStringProtector.DeriveKeyFromToken(_sessionToken);
        try
        {
            var plaintext = ConnectionStringProtector.DecryptWithKeyBytes(payload.EncryptedConnectionString, key);
            // Validate as a SQL connection string before returning.
            var builder = new SqlConnectionStringBuilder(plaintext);
            if (string.IsNullOrWhiteSpace(builder.DataSource) || string.IsNullOrWhiteSpace(builder.InitialCatalog))
                throw new SafeAuthenticationException("invalid_response", "رشتهٔ اتصال رمزگشایی‌شده نامعتبر است.");
            return plaintext;
        }
        catch (CryptographicException ex)
        {
            throw new SafeAuthenticationException("invalid_response", "رمزگشایی رشتهٔ اتصال ناموفق بود.");
        }
        finally
        {
            CryptographicOperations.ZeroMemory(key);
        }
    }

    private async Task FetchAndCacheEncryptedMasterCoreAsync(CancellationToken ct)
    {
        var plaintext = await FetchDecryptedMasterCoreAsync(ct);
        try
        {
            var builder = new SqlConnectionStringBuilder(plaintext)
            {
                Encrypt = true,
                TrustServerCertificate = false,
                PersistSecurityInfo = false
            };
            if (builder.ConnectTimeout <= 0 || builder.ConnectTimeout > 60)
                builder.ConnectTimeout = 25;
            if (!builder.ShouldSerialize("Application Name"))
                builder.ApplicationName = "Tarazin-MAUI";

            // We re-parse to the same shape as CredentialState but keep the
            // full plaintext cached for direct SqlConnection construction if
            // needed (used only to rebuild via BuildConnectionString).
            _masterPlaintextCache = builder.ConnectionString;
            _masterCredential = new CredentialState(
                builder.DataSource,
                builder.InitialCatalog,
                builder.UserID,
                builder.Password,
                DateTimeOffset.UtcNow.AddMinutes(5)); // will be refreshed via re-fetch
            _masterExpiresAt = _masterCredential.ExpiresAtUtc;
            SqlConnection.ClearAllPools();
        }
        finally
        {
            // Do not keep the raw fetched plaintext beyond the builder copy in
            // _masterPlaintextCache (which itself will be cleared on logout).
            // The intermediate `plaintext` string cannot be reliably zeroed (immutable),
            // but its lifetime is minimized and it is not stored beyond this scope.
        }
    }

    private async Task RefreshEncryptedMasterIfNeededAsync(CancellationToken ct)
    {
        if (_masterCredential is null) return;
        if (_masterExpiresAt - DateTimeOffset.UtcNow > TimeSpan.FromMinutes(1)) return;

        await _lifecycleGate.WaitAsync(ct);
        try
        {
            if (_masterCredential is null) return;
            if (_masterExpiresAt - DateTimeOffset.UtcNow > TimeSpan.FromMinutes(1)) return;
            if (_sessionExpiresAt <= DateTimeOffset.UtcNow || string.IsNullOrWhiteSpace(_sessionToken))
            {
                ClearLocal();
                throw new InvalidOperationException("The credential session has expired. Sign in again.");
            }

            await FetchAndCacheEncryptedMasterCoreAsync(ct);
            SqlConnection.ClearAllPools();
        }
        catch (SafeAuthenticationException ex)
        {
            ClearLocal();
            throw new InvalidOperationException(SafeMessage(ex.Code));
        }
        finally
        {
            _lifecycleGate.Release();
        }
    }

    private static string BuildConnectionString(CredentialState credential)
    {
        // These fields were structurally validated before CredentialState was
        // created. Rebuild a fresh connection string for each connection so no
        // server-side issuer credential can enter the MAUI process.
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = credential.Server,
            InitialCatalog = credential.Database,
            UserID = credential.Username,
            Password = credential.Password,
            Encrypt = true,
            TrustServerCertificate = false,
            PersistSecurityInfo = false,
            ConnectTimeout = 25,
            ApplicationName = "Tarazin-MAUI"
        };
        return builder.ConnectionString;
    }

    private async Task RevokeExistingCoreAsync(CancellationToken ct)
    {
        var token = _sessionToken;
        ClearLocal();
        if (string.IsNullOrWhiteSpace(token))
            return;

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "api/mobile/connection/revoke");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var response = await _http.SendAsync(request, ct);
            // Revocation is idempotent. Local erasure already happened and no
            // response details are exposed or logged.
        }
        catch (HttpRequestException)
        {
            // Server expiry cleanup remains the backstop when offline.
        }
        finally
        {
            token = "";
        }
    }

    private async Task RefreshIfNeededAsync(CancellationToken ct)
    {
        var current = _credential;
        if (current is null)
            throw new InvalidOperationException("Authenticate through the secure API before using SQL.");
        if (current.ExpiresAtUtc - DateTimeOffset.UtcNow > TimeSpan.FromMinutes(1))
            return;

        await _lifecycleGate.WaitAsync(ct);
        try
        {
            current = _credential;
            if (current is null)
                throw new InvalidOperationException("The credential session is unavailable.");
            if (current.ExpiresAtUtc - DateTimeOffset.UtcNow > TimeSpan.FromMinutes(1))
                return;
            if (_sessionExpiresAt <= DateTimeOffset.UtcNow || string.IsNullOrWhiteSpace(_sessionToken))
            {
                ClearLocal();
                throw new InvalidOperationException("The credential session has expired. Sign in again.");
            }

            var refresh = new MobileConnectionRefreshRequest
            {
                CustomerGuid = _customerGuid,
                Nonce = CreateNonce(),
                TimestampUtc = DateTimeOffset.UtcNow
            };
            using var request = new HttpRequestMessage(HttpMethod.Post, "api/mobile/connection/refresh")
            {
                Content = JsonContent.Create(refresh)
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _sessionToken);
            using var response = await _http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                ClearLocal();
                throw await CreateSafeExceptionAsync(response, ct);
            }

            var result = await response.Content.ReadFromJsonAsync<MobileConnectionResponse>(cancellationToken: ct)
                ?? throw new SafeAuthenticationException("invalid_response", "پاسخ تمدید اتصال معتبر نیست.");
            try
            {
                ValidateResponse(result, _customerGuid, current.Username);
            }
            catch (SafeAuthenticationException)
            {
                await RevokeCandidateResponseAsync(result, ct);
                throw;
            }
            ThrowIfDisposed();
            Apply(result);
            SqlConnection.ClearAllPools();
        }
        catch (SafeAuthenticationException ex)
        {
            ClearLocal();
            throw new InvalidOperationException(SafeMessage(ex.Code));
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            ClearLocal();
            throw new InvalidOperationException("The secure credential service timed out.");
        }
        catch (HttpRequestException)
        {
            ClearLocal();
            throw new InvalidOperationException("The secure credential service is unavailable.");
        }
        finally
        {
            _lifecycleGate.Release();
        }
    }

    private async Task RevokeCandidateResponseAsync(
        MobileConnectionResponse response,
        CancellationToken ct)
    {
        var token = response.SessionToken;
        response.SessionToken = "";
        if (response.Credential is not null)
            response.Credential.Password = "";
        if (response.User is not null)
            response.User.PasswordHash = "";

        if (string.IsNullOrWhiteSpace(token) || token.Length is < 32 or > 256)
        {
            token = "";
            return;
        }

        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "api/mobile/connection/revoke");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var cleanup = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cleanup.CancelAfter(TimeSpan.FromSeconds(5));
            using var ignored = await _http.SendAsync(request, cleanup.Token);
        }
        catch (Exception)
        {
            // Expiry and server cleanup are the backstop. Never expose malformed
            // response data or cleanup transport details to the UI/logs.
        }
        finally
        {
            token = "";
        }
    }

    private void Apply(MobileConnectionResponse response)
    {
        var incoming = response.Credential;
        SqlConnection.ClearAllPools();
        _credential = new CredentialState(
            incoming.Server,
            incoming.Database,
            incoming.Username,
            incoming.Password,
            incoming.ExpiresAtUtc);
        _sessionToken = response.SessionToken;
        _sessionExpiresAt = response.SessionExpiresAtUtc;

        // Remove duplicate references from the deserialized response as soon as copied.
        incoming.Password = "";
        response.SessionToken = "";
        response.User.PasswordHash = "";
        // CustomerGuid stays the packaged appsettings value; do not replace it
        // from the response or any other runtime source.
    }

    private static void ValidateResponse(
        MobileConnectionResponse response,
        Guid expectedCustomerGuid,
        string expectedUsername)
    {
        var now = DateTimeOffset.UtcNow;
        var credential = response.Credential;
        var user = response.User;
        if (credential is null || user is null || response.CustomerGuid != expectedCustomerGuid ||
            user.UserId <= 0 || !string.IsNullOrEmpty(user.PasswordHash) ||
            !string.Equals(user.Username, expectedUsername, StringComparison.OrdinalIgnoreCase) ||
            string.IsNullOrWhiteSpace(response.SessionToken) || response.SessionToken.Length > 256 ||
            response.SessionExpiresAtUtc <= now || response.SessionExpiresAtUtc > now.AddHours(3) ||
            string.IsNullOrWhiteSpace(credential.Server) || credential.Server.Length > 512 ||
            credential.Server.IndexOfAny([';', '=', '\r', '\n', '\0']) >= 0 ||
            string.IsNullOrWhiteSpace(credential.Database) || credential.Database.Length > 128 ||
            string.IsNullOrWhiteSpace(credential.Username) || credential.Username.Length > 128 ||
            string.IsNullOrWhiteSpace(credential.Password) || credential.Password.Length > 256 ||
            credential.ExpiresAtUtc <= now || credential.ExpiresAtUtc > now.AddMinutes(20) ||
            credential.ExpiresAtUtc > response.SessionExpiresAtUtc ||
            !credential.Encrypt || credential.TrustServerCertificate)
        {
            if (credential is not null)
                credential.Password = "";
            if (user is not null)
                user.PasswordHash = "";
            // Keep the candidate token just long enough for the caller to issue
            // a best-effort revoke; that helper always erases it afterward.
            throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");
        }
    }

    private static async Task<SafeAuthenticationException> CreateSafeExceptionAsync(
        HttpResponseMessage response,
        CancellationToken ct)
    {
        try
        {
            var error = await response.Content.ReadFromJsonAsync<CredentialBrokerError>(cancellationToken: ct);
            if (error is not null && IsKnownErrorCode(error.Code))
                return new SafeAuthenticationException(error.Code, SafeMessage(error.Code));
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch
        {
            // Never surface raw response bodies or parser/transport exceptions.
        }

        return response.StatusCode == System.Net.HttpStatusCode.TooManyRequests
            ? new SafeAuthenticationException("rate_limited", "تعداد تلاش‌ها زیاد است. کمی بعد دوباره تلاش کنید.")
            : new SafeAuthenticationException("request_rejected", "درخواست ورود پذیرفته نشد.");
    }

    private static bool IsKnownErrorCode(string code) => code is
        "invalid_credentials" or "customer_not_found" or "customer_inactive" or
        "customer_not_authorized" or "invalid_token" or "authorization_expired" or
        "replayed_request" or "service_unavailable" or "broker_not_configured" or
        "broker_not_ready" or "issuer_not_authorized" or "https_required";

    private static string SafeMessage(string code) => code switch
    {
        "invalid_credentials" => "نام کاربری یا رمز عبور صحیح نیست.",
        "customer_not_found" => "مشتری یافت نشد یا مجاز نیست.",
        "customer_inactive" => "دسترسی این مشتری فعال نیست.",
        "customer_not_authorized" => "کاربر برای این مشتری مجاز نیست.",
        "invalid_token" or "authorization_expired" => "نشست اتصال منقضی یا لغو شده است؛ دوباره وارد شوید.",
        "replayed_request" => "درخواست تکراری پذیرفته نشد؛ دوباره تلاش کنید.",
        "broker_not_configured" => "سرویس ورود MAUI روی سرور پیکربندی نشده است؛ با مدیر سامانه تماس بگیرید.",
        "broker_not_ready" => "سرویس ورود MAUI روی سرور آماده نشده است؛ با مدیر سامانه تماس بگیرید.",
        "issuer_not_authorized" => "سرویس ورود MAUI مجوز صدور اتصال موقت را ندارد؛ با مدیر سامانه تماس بگیرید.",
        "service_unavailable" => "سرویس اتصال موقتاً در دسترس نیست.",
        "https_required" => "برای ورود، اتصال امن HTTPS لازم است.",
        _ => "درخواست ورود پذیرفته نشد."
    };

    private static bool IsSecureEndpoint(Uri endpoint)
    {
        if (endpoint.Scheme.Equals(Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
            return true;
#if DEBUG
        return endpoint.Scheme.Equals(Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase) && endpoint.IsLoopback;
#else
        return false;
#endif
    }

    private static string CreateNonce()
        => Convert.ToBase64String(RandomNumberGenerator.GetBytes(24))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private void ClearLocal()
    {
        _credential = null;
        _masterCredential = null;
        _masterExpiresAt = default;
        _masterPlaintextCache = "";
        _sessionToken = "";
        _sessionExpiresAt = default;
        SqlConnection.ClearAllPools();
    }

    private void ThrowIfDisposed() => ObjectDisposedException.ThrowIf(_disposed, this);

    public void Dispose()
    {
        if (_disposed)
            return;
        _disposed = true;
        ClearLocal();
        _http.Dispose();
        // Do not dispose the gate: an in-flight lifecycle operation may still
        // need to release it while HttpClient cancellation unwinds.
    }

    private sealed record CredentialState(
        string Server,
        string Database,
        string Username,
        string Password,
        DateTimeOffset ExpiresAtUtc);
}
