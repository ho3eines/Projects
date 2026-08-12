using System.Net.Http.Json;
using BlazorDeployService.Models;
using Newtonsoft.Json;

namespace BlazorDeployService.Services;

public partial class RequestService
{
    private async Task<List<T>?> HermesRequest<T>(string scriptName, object? param, bool isExec, bool isScalar, string userCode = "", bool allowRetry = true) where T : class
    {
        if (string.IsNullOrWhiteSpace(_projectGuid))
        {
            await _alertService.ShowErrorAsync("پیکربندی", "ProjectGuid تنظیم نشده است");
            return null;
        }

        var session = await EnsureHermesSessionAsync();
        if (session is null)
            return null;

        var bag = JsonConvert.SerializeObject(new
        {
            token = Guid.NewGuid().ToString(),
            requestDate = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"),
            connectionString = "",
            IsExec = isExec,
            SqlStr = scriptName,
            Parameters = param,
            userCode,
            ExpairDate = DateTime.UtcNow.AddMinutes(5).ToString("yyyy-MM-dd HH:mm:ss"),
            token2 = Guid.NewGuid().ToString(),
            IsScalar = isScalar
        });

        var enc = await _enc.EncryptDataAsync(bag, session.Value.EncryptionKey);

        _http.DefaultRequestHeaders.Clear();
        _http.DefaultRequestHeaders.Add("X-API-Key", session.Value.Token);
        _http.DefaultRequestHeaders.Add("X-Project-Guid", _projectGuid);

        var response = await _http.PostAsJsonAsync(BaseUrl + "Data/", enc);
        var responseData = await response.Content.ReadAsStringAsync();
        var res = JsonConvert.DeserializeObject<responeData>(responseData);
        if (res is null)
            return null;

        if (res.code == 401)
        {
            InvalidateSession();
            if (!allowRetry)
                return null;
            if (await EnsureHermesSessionAsync() is null)
                return null;
            return await HermesRequest<T>(scriptName, param, isExec, isScalar, userCode, allowRetry: false);
        }

        if (res.code != 200)
        {
            await _alertService.ShowErrorAsync("خطا", res.message ?? "درخواست ناموفق");
            return null;
        }

        if (isExec)
            return null;

        if (string.IsNullOrEmpty(res.data))
            return new List<T>();

        var plain = await _enc.DecryptDataAsync(res.data, session.Value.EncryptionKey);
        return JsonConvert.DeserializeObject<List<T>>(plain) ?? new List<T>();
    }

    private async Task<(string Token, string EncryptionKey)?> EnsureHermesSessionAsync()
    {
        if (!string.IsNullOrEmpty(_sessionToken)
            && !string.IsNullOrEmpty(_sessionEncKey)
            && DateTime.UtcNow < _sessionExpiresUtc.AddMinutes(-1))
        {
            return (_sessionToken, _sessionEncKey);
        }

        var handshake = new
        {
            projectGuid = _projectGuid,
            timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            nonce = Guid.NewGuid().ToString("N")
        };

        string enc;
        try
        {
            enc = await _enc.EncryptDataAsync(JsonConvert.SerializeObject(handshake), _encryption);
        }
        catch (Exception ex)
        {
            await _alertService.ShowErrorAsync("رمزنگاری", ex.Message);
            return null;
        }

        _http.DefaultRequestHeaders.Clear();
        _http.DefaultRequestHeaders.Add("X-Project-Guid", _projectGuid);

        HttpResponseMessage response;
        try
        {
            response = await _http.PostAsJsonAsync(BaseUrl + "auth/handshake", new { data = enc });
        }
        catch (Exception ex)
        {
            await _alertService.ShowErrorAsync("Handshake", ex.Message);
            return null;
        }

        var raw = await response.Content.ReadAsStringAsync();
        var res = JsonConvert.DeserializeObject<responeData>(raw);
        if (res is null || res.code != 200 || string.IsNullOrEmpty(res.data))
        {
            await _alertService.ShowErrorAsync("Handshake", res?.message ?? $"HTTP {(int)response.StatusCode}");
            return null;
        }

        string inner;
        try
        {
            inner = await _enc.DecryptDataAsync(res.data, _encryption);
        }
        catch (Exception ex)
        {
            await _alertService.ShowErrorAsync("Handshake", "Decrypt failed: " + ex.Message);
            return null;
        }

        var session = JsonConvert.DeserializeObject<HermesHandshakeInner>(inner);
        if (session is null || string.IsNullOrEmpty(session.RequestId) || string.IsNullOrEmpty(session.EncryptionKey))
        {
            await _alertService.ShowErrorAsync("Handshake", "پاسخ نشست ناقص است");
            return null;
        }

        _sessionToken = session.RequestId;
        _sessionEncKey = session.EncryptionKey;
        _sessionExpiresUtc = session.ExpiresAt == default
            ? DateTime.UtcNow.AddMinutes(14)
            : session.ExpiresAt.ToUniversalTime();

        return (_sessionToken, _sessionEncKey);
    }

    private void InvalidateSession()
    {
        _sessionToken = null;
        _sessionEncKey = null;
        _sessionExpiresUtc = DateTime.MinValue;
    }

    private sealed class HermesHandshakeInner
    {
        public string? RequestId { get; set; }
        public string? EncryptionKey { get; set; }
        public DateTime ExpiresAt { get; set; }
        public string? Schema { get; set; }
    }
}
