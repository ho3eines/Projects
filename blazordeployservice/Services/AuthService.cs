using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using BlazorDeployService.Helper;
using BlazorDeployService.Models;
using Microsoft.Extensions.Options;

namespace BlazorDeployService.Services;

/// <summary>
/// احراز هویت کلاینت با webapi:
/// 1) LoginToken + ProjectGuid را با EncryptionKey پروژه AES-انکریپت می‌کند
/// 2) به /api/auth/login می‌فرستد (همراه X-Api-Key پروژه)
/// 3) SessionToken دریافت می‌کند → SessionService ذخیره می‌کند
/// </summary>
public interface IAuthService
{
    Task<LoginResponse> LoginAsync(Guid projectGuid, string loginToken, CancellationToken ct = default);
    Task LogoutAsync();
}

public sealed class AuthService : IAuthService
{
    private readonly HttpClient _http;
    private readonly AppSettings _settings;
    private readonly IEncryptionService _encryption;
    private readonly ISessionService _session;

    public AuthService(
        HttpClient http,
        IOptions<AppSettings> settings,
        IEncryptionService encryption,
        ISessionService session)
    {
        _http = http;
        _settings = settings.Value;
        _encryption = encryption;
        _session = session;

        // اعمال مهلت درخواست تنظیم‌شده در appsettings
        if (_settings.ApiSettings.Timeout > 0 &&
            _http.Timeout != TimeSpan.FromMilliseconds(_settings.ApiSettings.Timeout))
        {
            _http.Timeout = TimeSpan.FromMilliseconds(_settings.ApiSettings.Timeout);
        }
    }

    public async Task<LoginResponse> LoginAsync(Guid projectGuid, string loginToken, CancellationToken ct = default)
    {
        // 1) رمزنگاری LoginToken با کلید پروژه
        var encryptedToken = await _encryption.EncryptDataAsync(loginToken, _settings.Encryption.Key);

        var request = new LoginRequest
        {
            ProjectGuid = projectGuid,
            LoginToken = encryptedToken,
            ClientVersion = "1.0.100"
        };

        // ساخت URL بدون اسلش تکراری — BaseUrl ممکن است با "/" تمام شده باشد
        var url = ApiUrl.Combine(_settings.ApiSettings.BaseUrl, "/api/auth/login");
        using var httpReq = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = JsonContent.Create(request)
        };
        httpReq.Headers.Add("X-Api-Key", _settings.ApiSettings.APIKey);

        HttpResponseMessage response;
        try
        {
            response = await _http.SendAsync(httpReq, ct);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new AuthException("مهلت درخواست ورود به پایان رسید — لطفاً دوباره تلاش کنید.", 0);
        }
        catch (HttpRequestException)
        {
            throw new AuthException("اتصال به سرور برقرار نشد — وضعیت شبکه یا در دسترس بودن سرور را بررسی کنید.", 0);
        }

        using (response)
        {
            var raw = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                throw new AuthException(
                    $"ورود ناموفق ({(int)response.StatusCode}): {raw}",
                    (int)response.StatusCode);
            }

            var result = JsonSerializer.Deserialize<LoginResponse>(raw, JsonOpts);
            if (result is null || string.IsNullOrEmpty(result.SessionToken))
                throw new AuthException("پاسخ سرور معتبر نیست", 500);

            // ذخیره نشست
            await _session.StartSessionAsync(result);
            return result;
        }
    }

    public async Task LogoutAsync()
    {
        await _session.EndSessionAsync("logout");
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true
    };
}

public sealed class AuthException : Exception
{
    public int StatusCode { get; }
    public AuthException(string message, int statusCode) : base(message) => StatusCode = statusCode;
}