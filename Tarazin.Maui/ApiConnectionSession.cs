using System.Net.Http.Json;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Tarazin.Data;
using Tarazin.Models;
using Tarazin.Services;

namespace Tarazin.Maui;

/// <summary>
/// MAUI connection session (simplified 2026-08-20, product-owner decision).
/// Login sends username/password to the Web host over HTTPS
/// (<c>POST /api/mobile/login</c>); the server verifies them against
/// [central].[Users] and returns the SQL connection string of its own
/// configuration, encrypted with AES-256-CBC under a key derived from the
/// login password (SHA-256). This class derives the same key from the typed
/// password, decrypts the string, and keeps the plaintext in process memory
/// only — handed to the shared UI/data layer (ISqlConnectionProvider →
/// DbService) for direct SQL execution. The decrypted/cached value is never
/// written to preferences, files, SecureStorage, logs, or configuration, and
/// is erased on logout (<see cref="RevokeAndClearAsync"/>).
/// </summary>
public sealed class ApiConnectionSession :
    ISqlConnectionProvider,
    IRemoteAuthenticationService,
    ICredentialSessionRevoker,
    IDisposable
{
    private readonly HttpClient _http;
    private string? _connectionString; // decrypted, in-memory only
    private string _database = "";
    private bool _disposed;

    public ApiConnectionSession(IConfiguration configuration)
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

    public bool IsAvailable => _connectionString is not null;
    public bool SupportsInitialization => false;

    public string DatabaseName => _database;

    public string Description => _connectionString is not null
        ? "اتصال SQL رمزگذاری‌شدهٔ دریافت‌شده از API (AES با کلید مشتق از رمز ورود) — اجرا در UI"
        : "رشتهٔ اتصال از API دریافت نشده است";

    public async Task<UserRow?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken ct = default)
    {
        ThrowIfDisposed();

        var request = new MobileLoginRequest { Username = username, Password = password };
        try
        {
            using var response = await _http.PostAsJsonAsync("api/mobile/login", request, ct);
            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
                return null; // نام کاربری یا رمز عبور صحیح نیست.

            if (!response.IsSuccessStatusCode)
                throw await CreateSafeExceptionAsync(response, ct);

            var result = await response.Content.ReadFromJsonAsync<MobileLoginResponse>(cancellationToken: ct);
            if (result?.User is null || result.User.UserId <= 0 ||
                string.IsNullOrWhiteSpace(result.EncryptedConnectionString) ||
                !result.EncryptedConnectionString.StartsWith(ConnectionStringProtector.EncryptedPrefix, StringComparison.Ordinal))
                throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");

            // The server encrypted with SHA-256(password); the same typed
            // password decrypts. A mismatch can only mean a corrupted response.
            var key = ConnectionStringProtector.DeriveKeyFromSecret(password);
            string plaintext;
            try
            {
                plaintext = ConnectionStringProtector.DecryptWithKeyBytes(result.EncryptedConnectionString, key);
            }
            catch (CryptographicException)
            {
                throw new SafeAuthenticationException("invalid_response", "رمزگشایی رشتهٔ اتصال ناموفق بود.");
            }
            catch (FormatException)
            {
                throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");
            }
            catch (ArgumentException)
            {
                throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");
            }
            finally
            {
                CryptographicOperations.ZeroMemory(key);
            }

            var builder = new SqlConnectionStringBuilder(plaintext)
            {
                Encrypt = true,
                // Certificate validation disabled by operator decision
                // (2026-08-20): same policy as the server-side TarazinConnection
                // so the local SQL Server self-signed certificate is accepted.
                TrustServerCertificate = true,
                PersistSecurityInfo = false
            };
            if (string.IsNullOrWhiteSpace(builder.DataSource) || string.IsNullOrWhiteSpace(builder.InitialCatalog))
                throw new SafeAuthenticationException("invalid_response", "رشتهٔ اتصال رمزگشایی‌شده نامعتبر است.");
            if (builder.ConnectTimeout <= 0 || builder.ConnectTimeout > 60)
                builder.ConnectTimeout = 25;
            if (!builder.ShouldSerialize("Application Name"))
                builder.ApplicationName = "Tarazin-MAUI";

            ThrowIfDisposed();
            _connectionString = builder.ConnectionString;
            _database = builder.InitialCatalog;
            result.User.PasswordHash = "";
            SqlConnection.ClearAllPools();
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
        catch (System.Text.Json.JsonException)
        {
            throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");
        }
        catch (NotSupportedException)
        {
            throw new SafeAuthenticationException("invalid_response", "پاسخ سرویس اتصال معتبر نیست.");
        }
        finally
        {
            request.Password = "";
        }
    }

    public async ValueTask<SqlConnection> OpenConnectionAsync(CancellationToken ct = default)
    {
        ThrowIfDisposed();
        var connectionString = _connectionString
            ?? throw new InvalidOperationException("رشتهٔ اتصال از API دریافت نشده است؛ دوباره وارد شوید.");

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

    /// <summary>Logout: erase the in-memory connection string and pooled connections. No server call is needed.</summary>
    public Task RevokeAndClearAsync(CancellationToken ct = default)
    {
        ClearLocal();
        return Task.CompletedTask;
    }

    private static async Task<SafeAuthenticationException> CreateSafeExceptionAsync(
        HttpResponseMessage response,
        CancellationToken ct)
    {
        try
        {
            var error = await response.Content.ReadFromJsonAsync<MobileConnectionError>(cancellationToken: ct);
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
            : new SafeAuthenticationException("service_unavailable", "سرویس اتصال موقتاً در دسترس نیست.");
    }

    private static bool IsKnownErrorCode(string code) => code is
        "invalid_credentials" or "invalid_request" or "service_unavailable" or "https_required";

    private static string SafeMessage(string code) => code switch
    {
        "invalid_credentials" => "نام کاربری یا رمز عبور صحیح نیست.",
        "invalid_request" => "درخواست ورود معتبر نیست.",
        "https_required" => "برای ورود، اتصال امن HTTPS لازم است.",
        "service_unavailable" => "سرویس اتصال موقتاً در دسترس نیست.",
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

    private void ClearLocal()
    {
        _connectionString = null;
        _database = "";
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
    }
}
