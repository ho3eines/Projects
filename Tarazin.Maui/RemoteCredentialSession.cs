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
/// MAUI-only connection session. Authenticates through the web broker
/// (<c>api/mobile/connection/login</c>) and then fetches the server-managed SQL
/// connection string from the web endpoint <c>api/{guid}</c>. The connection
/// string is retained only in this process instance and is never written to
/// preferences, files, SecureStorage, logs, or configuration.
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
    private Guid _customerGuid;
    private string _sessionToken = "";
    private DateTimeOffset _sessionExpiresAt;
    private CredentialState? _credential;
    // Server-managed SQL connection string served by the web endpoint api/{guid}.
    // Held only in this process instance; never persisted or logged.
    private string _connectionString = "";
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
        _http = new HttpClient
        {
            BaseAddress = normalizedEndpoint,
            Timeout = TimeSpan.FromSeconds(25),
            MaxResponseContentBufferSize = 64 * 1024
        };
        _http.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("Tarazin-MAUI/1.0");
    }

    public bool IsAvailable => !string.IsNullOrWhiteSpace(_connectionString);
    public bool SupportsInitialization => false;

    public string DatabaseName
    {
        get
        {
            if (string.IsNullOrWhiteSpace(_connectionString))
                return "";
            try
            {
                return new SqlConnectionStringBuilder(_connectionString).InitialCatalog ?? "";
            }
            catch
            {
                return "";
            }
        }
    }

    public string Description => string.IsNullOrWhiteSpace(_connectionString)
        ? "اتصال از سرویس وب آماده نیست"
        : "اتصال SQL دریافت‌شده از سرویس وب";

    public async Task<UserRow?> AuthenticateAsync(
        string username,
        string password,
        Guid customerGuid,
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

            request = new MobileConnectionRequest
            {
                Username = username,
                Password = password,
                CustomerGuid = customerGuid,
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
                ValidateResponse(result, customerGuid, username.Trim());
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
            // The SQL connection is served by the web endpoint api/{guid}. If the
            // connection fetch fails, discard the just-issued broker session too.
            try
            {
                _connectionString = await FetchConnectionStringAsync(customerGuid, ct);
            }
            catch
            {
                await RevokeExistingCoreAsync(ct);
                throw;
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
        var connectionString = _connectionString;
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("Authenticate through the API before using SQL.");

        var connection = new SqlConnection(connectionString);
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

    private async Task<string> FetchConnectionStringAsync(Guid customerGuid, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, $"api/{customerGuid:N}");
        using var response = await _http.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
            throw await CreateSafeExceptionAsync(response, ct);

        var payload = await response.Content.ReadFromJsonAsync<ConnectionStringPayload>(cancellationToken: ct);
        if (payload is null || string.IsNullOrWhiteSpace(payload.ConnectionString))
            throw new SafeAuthenticationException("invalid_response", "پاسخ اتصال سرویس معتبر نیست.");

        try
        {
            return NormalizeConnectionString(payload.ConnectionString);
        }
        catch (ArgumentException)
        {
            throw new SafeAuthenticationException("invalid_response", "پاسخ اتصال سرویس معتبر نیست.");
        }
    }

    // Re-emit the server-provided connection string with a hard safety baseline so
    // a compromised/misconfigured server cannot silently disable transport
    // encryption or certificate validation.
    private static string NormalizeConnectionString(string connectionString)
    {
        var builder = new SqlConnectionStringBuilder(connectionString)
        {
            Encrypt = true,
            TrustServerCertificate = false,
            PersistSecurityInfo = false
        };
#if DEBUG
        builder.TrustServerCertificate = !false;
#endif
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
        _customerGuid = response.CustomerGuid;
        _sessionToken = response.SessionToken;
        _sessionExpiresAt = response.SessionExpiresAtUtc;

        // Remove duplicate references from the deserialized response as soon as copied.
        incoming.Password = "";
        response.SessionToken = "";
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
        "replayed_request" or "service_unavailable" or "https_required";

    private static string SafeMessage(string code) => code switch
    {
        "invalid_credentials" => "نام کاربری یا رمز عبور صحیح نیست.",
        "customer_not_found" => "مشتری یافت نشد یا مجاز نیست.",
        "customer_inactive" => "دسترسی این مشتری فعال نیست.",
        "customer_not_authorized" => "کاربر برای این مشتری مجاز نیست.",
        "invalid_token" or "authorization_expired" => "نشست اتصال منقضی یا لغو شده است؛ دوباره وارد شوید.",
        "replayed_request" => "درخواست تکراری پذیرفته نشد؛ دوباره تلاش کنید.",
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
        _sessionToken = "";
        _sessionExpiresAt = default;
        _customerGuid = default;
        _connectionString = "";
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
