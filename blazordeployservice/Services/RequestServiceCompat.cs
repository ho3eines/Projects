using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using BlazorDeployService.Helper;
using BlazorDeployService.Models;

namespace BlazorDeployService.Services;

/// <summary>Legacy (Hermes v1) API result shape — kept for central-client.</summary>
public sealed class HermesLoginResult
{
    public string UserToken { get; set; } = "";
    public int UserId { get; set; }
    public string Username { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Role { get; set; } = "";
}

/// <summary>
/// Legacy compatibility layer (Hermes v1 API on top of the v2 transport).
///
/// All pre-v2 clients (accounting, central-client and the 7-product clients)
/// call the old surface — Request&lt;T&gt;(scriptName, params, isExec),
/// SetUserToken / UserToken and LoginAsync(user, pass). This partial class
/// implements those members using the v2 pipeline:
///
///   query  → POST /api/request/script (named script, per-project schema folder)
///   exec   → same endpoint (server executes the non-SELECT script)
///   login  → POST /api/auth/login with the project's AES-encrypted login token
///            (auto-login happens lazily before the first data call)
/// </summary>
public sealed partial class RequestService
{
    private string? _compatUserToken;

    /// <summary>Current session token (or the stored token before login).</summary>
    public string? UserToken => !string.IsNullOrEmpty(_session.SessionToken) ? _session.SessionToken : _compatUserToken;

    /// <summary>
    /// Stores a user/login token (legacy flow: central-client passes it to
    /// product apps via ?token=). Passing null ends the session.
    /// </summary>
    public void SetUserToken(string? token)
    {
        _compatUserToken = string.IsNullOrWhiteSpace(token) ? null : token.Trim();
        if (_compatUserToken is null)
        {
            _ = _session.EndSessionAsync("logout");
        }
        else
        {
            _storage.SetLocalAsync("hermes:user-token", _compatUserToken).GetAwaiter().GetResult();
        }
    }

    /// <summary>
    /// Legacy login (username/password). v2 has no user/password store on the
    /// webapi, so this logs the current project in with its configured login
    /// token and returns a session-shaped result.
    /// </summary>
    public async Task<HermesLoginResult?> LoginAsync(string username, string password)
    {
        var loggedIn = _session.Status == SessionStatus.Active && !string.IsNullOrEmpty(_session.SessionToken);
        if (!loggedIn)
            loggedIn = await _session.RestoreSessionAsync();

        if (!loggedIn)
        {
            var loginToken = _compatUserToken ?? _settings.ApiSettings.LoginToken ?? "hermes-admin";
            // در صورت خطا، LoginCoreAsync استثنای قابل نمایش پرتاب می‌کند
            var response = await LoginCoreAsync(loginToken);
            if (response is null)
                throw new RequestServiceException("پاسخ سرور معتبر نیست — لطفاً دوباره تلاش کنید.", "EMPTY_RESPONSE");
        }

        return new HermesLoginResult
        {
            UserToken = _session.SessionToken ?? "",
            UserId = 0,
            Username = username,
            DisplayName = "مدیر سیستم",
            Role = "Admin"
        };
    }

    public Task<List<T>> GetData<T>(string sql, object parameters = null) where T : class
        => RunScriptAsync<T>(sql, parameters);

    public Task PrintToPdf(string reportPath, System.Data.DataTable dt) => Task.CompletedTask;

    /// <summary>Legacy named-script call.</summary>
    public Task<List<T>?> Request<T>(string scriptName, object? parameters = null, bool isExec = false,
        string? connectionstring = null, string userCode = "") where T : class
    {
        if (isExec)
            return RequestExecAsync<T>(scriptName, parameters);
        return RequestQueryAsync<T>(scriptName, parameters);
    }

    private async Task<List<T>?> RequestQueryAsync<T>(string scriptName, object? parameters) where T : class
    {
        await EnsureLoginAsync();
        return await RunScriptAsync<T>(scriptName, parameters);
    }

    private async Task<List<T>?> RequestExecAsync<T>(string scriptName, object? parameters) where T : class
    {
        await EnsureLoginAsync();
        // The server's "script" endpoint executes the named script; non-SELECT
        // scripts return an empty result set, which is all callers need.
        await RunScriptAsync<T>(scriptName, parameters);
        return default;
    }

    /// <summary>Ensures an active v2 session, logging in when needed.</summary>
    private async Task<LoginResponse?> EnsureLoginAsync()
    {
        if (_session.Status == SessionStatus.Active && !string.IsNullOrEmpty(_session.SessionToken))
            return null;

        if (await _session.RestoreSessionAsync())
            return null;

        var loginToken = _compatUserToken ?? _settings.ApiSettings.LoginToken ?? "hermes-admin";
        try
        {
            return await LoginCoreAsync(loginToken);
        }
        catch
        {
            // fall through — try the configured token
        }

        // The stored token may be a cross-project session token (central-client
        // passes its own token via ?token=) — fall back to the project's own
        // configured login token before giving up.
        if (!string.IsNullOrEmpty(_settings.ApiSettings.LoginToken) &&
            !string.Equals(_settings.ApiSettings.LoginToken, loginToken, StringComparison.Ordinal))
        {
            try
            {
                return await LoginCoreAsync(_settings.ApiSettings.LoginToken!);
            }
            catch
            {
                return null; // the data call will surface the real error
            }
        }

        return null;
    }

    /// <summary>v2 login: AES-encrypt the login token, POST /api/auth/login.</summary>
    /// در صورت خطا (شبکه، مهلت یا پاسخ ناموفق سرور) استثنای قابل نمایش پرتاب می‌کند.
    private async Task<LoginResponse?> LoginCoreAsync(string loginToken)
    {
        var encryptedToken = await _encryption.EncryptDataAsync(loginToken, _settings.Encryption.Key);

        var request = new LoginRequest
        {
            ProjectGuid = ResolveProjectGuid(),
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
            response = await _http.SendAsync(httpReq);
        }
        catch (OperationCanceledException)
        {
            throw new RequestServiceException("مهلت درخواست ورود به پایان رسید — لطفاً دوباره تلاش کنید.", "TIMEOUT");
        }
        catch (HttpRequestException)
        {
            throw new RequestServiceException("اتصال به سرور برقرار نشد — وضعیت شبکه یا در دسترس بودن سرور را بررسی کنید.", "NETWORK");
        }

        using (response)
        {
            var raw = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
                throw new RequestServiceException(
                    BuildLoginError(raw, (int)response.StatusCode),
                    response.StatusCode.ToString());

            var result = JsonSerializer.Deserialize<LoginResponse>(raw, JsonOpts);
            if (result is null || string.IsNullOrEmpty(result.SessionToken))
                return null;

            await _session.StartSessionAsync(result);
            return result;
        }
    }

    /// <summary>پیام خطای خوانا از پاسخ سرور — فیلد error یا message را استخراج می‌کند</summary>
    private static string BuildLoginError(string raw, int statusCode)
    {
        var fallback = $"ورود ناموفق ({statusCode}) — لطفاً دوباره تلاش کنید.";
        if (string.IsNullOrWhiteSpace(raw))
            return fallback;

        try
        {
            using var doc = JsonDocument.Parse(raw);
            if (doc.RootElement.TryGetProperty("error", out var err) &&
                err.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(err.GetString()))
                return err.GetString()!;
            if (doc.RootElement.TryGetProperty("message", out var msg) &&
                msg.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(msg.GetString()))
                return msg.GetString()!;
        }
        catch (JsonException)
        {
            // متن ساده است — پایین برمی‌گردد
        }

        var trimmed = raw.Trim();
        return trimmed.Length <= 200 ? trimmed : trimmed[..200] + "…";
    }
}
