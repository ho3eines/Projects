using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Share.Models;

namespace Share.Services;

public interface ISystemApi
{
    void SetAccessToken(string? token);
    void TrySetTokenFromUri(string absoluteUri);

    Task<SystemQueryResult<T>> QueryAsync<T>(string scriptName, object? parameters = null, string? schema = null, CancellationToken cancellationToken = default);
    Task<SystemExecuteResult> ExecuteAsync(string scriptName, object? parameters = null, string? schema = null, CancellationToken cancellationToken = default);
    Task<SystemScalarResult<T>> ScalarAsync<T>(string scriptName, object? parameters = null, string? schema = null, CancellationToken cancellationToken = default);
}

/// <summary>OBSOLETE. Clients must use IRequestService (Protocol=Hermes). /api/system is not routed.</summary>
[Obsolete("Use IRequestService with Protocol=Hermes. Do not call /api/system.")]
public sealed class SystemApi : ISystemApi
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly HttpClient _http;
    private string? _token;

    public SystemApi(HttpClient http)
    {
        _http = http;
    }

    public void SetAccessToken(string? token) => _token = string.IsNullOrWhiteSpace(token) ? null : token.Trim();

    public void TrySetTokenFromUri(string absoluteUri)
    {
        if (!Uri.TryCreate(absoluteUri, UriKind.Absolute, out var uri))
            return;

        var query = uri.Query.TrimStart('?');
        foreach (var part in query.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var kv = part.Split('=', 2);
            if (kv.Length == 2 && kv[0].Equals("token", StringComparison.OrdinalIgnoreCase))
            {
                SetAccessToken(Uri.UnescapeDataString(kv[1]));
                return;
            }
        }
    }

    public Task<SystemQueryResult<T>> QueryAsync<T>(string scriptName, object? parameters = null, string? schema = null, CancellationToken cancellationToken = default)
        => SendAsync<SystemQueryResult<T>>("api/system/query", scriptName, parameters, schema, cancellationToken);

    public Task<SystemExecuteResult> ExecuteAsync(string scriptName, object? parameters = null, string? schema = null, CancellationToken cancellationToken = default)
        => SendAsync<SystemExecuteResult>("api/system/execute", scriptName, parameters, schema, cancellationToken);

    public Task<SystemScalarResult<T>> ScalarAsync<T>(string scriptName, object? parameters = null, string? schema = null, CancellationToken cancellationToken = default)
        => SendAsync<SystemScalarResult<T>>("api/system/scalar", scriptName, parameters, schema, cancellationToken);

    private async Task<T> SendAsync<T>(string url, string scriptName, object? parameters, string? schema, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(scriptName))
            throw new ArgumentException("ScriptName is required", nameof(scriptName));

        var payload = new SystemRequestPayload
        {
            ScriptName = scriptName.Trim(),
            Schema = string.IsNullOrWhiteSpace(schema) ? null : schema.Trim(),
            RequestId = Guid.NewGuid().ToString(),
            Parameters = parameters is null ? null : JsonSerializer.SerializeToElement(parameters, JsonOpts)
        };

        using var req = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(JsonSerializer.Serialize(payload, JsonOpts), Encoding.UTF8, "application/json")
        };

        if (!string.IsNullOrEmpty(_token))
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _token);

        using var res = await _http.SendAsync(req, cancellationToken);
        var body = await res.Content.ReadAsStringAsync(cancellationToken);

        if (!res.IsSuccessStatusCode)
            throw new SystemApiException(res.StatusCode, payload.RequestId, payload.ScriptName, body);

        var parsed = JsonSerializer.Deserialize<T>(body, JsonOpts);
        if (parsed is null)
            throw new SystemApiException(res.StatusCode, payload.RequestId, payload.ScriptName, "Empty or invalid JSON from webapi.");

        return parsed;
    }
}

public sealed class SystemApiException : Exception
{
    public HttpStatusCode StatusCode { get; }
    public string? RequestId { get; }
    public string ScriptName { get; }

    public SystemApiException(HttpStatusCode statusCode, string? requestId, string scriptName, string body)
        : base($"Hermes TSQL '{scriptName}' failed ({(int)statusCode}): {TrimBody(body)}")
    {
        StatusCode = statusCode;
        RequestId = requestId;
        ScriptName = scriptName;
    }

    private static string TrimBody(string body)
        => string.IsNullOrWhiteSpace(body) ? "(no body)" : (body.Length <= 500 ? body : body[..500] + "…");
}
