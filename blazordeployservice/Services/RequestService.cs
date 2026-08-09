using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.JSInterop;

namespace BlazorDeployService.Services;

/// <summary>
/// Central RequestService — the ONLY way clients talk to webapi.
/// Pattern: single endpoint /api/system that executes named TSQL files.
/// </summary>
public interface IRequestService
{
    Task<List<T>> QueryAsync<T>(string scriptName, object? parameters = null);
    Task<T?> QueryFirstAsync<T>(string scriptName, object? parameters = null);
    Task<int> ExecuteAsync(string scriptName, object? parameters = null);
    Task<T> ScalarAsync<T>(string scriptName, object? parameters = null);
    void SetBaseAddress(string baseAddress);
    void SetAuthToken(string? token);
}

public class RequestService : IRequestService
{
    private readonly HttpClient _http;
    private readonly IJSRuntime _js;
    private string _baseAddress = "";
    private string? _authToken;

    public RequestService(HttpClient http, IJSRuntime js)
    {
        _http = http;
        _js = js;
    }

    public void SetBaseAddress(string baseAddress)
    {
        _baseAddress = baseAddress.TrimEnd('/');
        _http.BaseAddress = new Uri(_baseAddress);
    }

    public void SetAuthToken(string? token)
    {
        _authToken = token;
        _http.DefaultRequestHeaders.Remove("Authorization");
        if (!string.IsNullOrEmpty(token))
            _http.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");
    }

    /// <summary>POST /api/system/query — executes named TSQL file, returns list</summary>
    public async Task<List<T>> QueryAsync<T>(string scriptName, object? parameters = null)
    {
        var payload = new SystemRequestPayload
        {
            ScriptName = scriptName,
            Parameters = parameters is null ? null : JsonSerializer.SerializeToElement(parameters),
            RequestId = Guid.NewGuid().ToString()
        };

        var resp = await _http.PostAsJsonAsync("/api/system/query", payload);
        resp.EnsureSuccessStatusCode();

        var result = await resp.Content.ReadFromJsonAsync<SystemQueryResult<T>>();
        return result?.Data ?? new List<T>();
    }

    public async Task<T?> QueryFirstAsync<T>(string scriptName, object? parameters = null)
    {
        var list = await QueryAsync<T>(scriptName, parameters);
        return list.FirstOrDefault();
    }

    /// <summary>POST /api/system/execute — runs TSQL (INSERT/UPDATE/DELETE/DDL)</summary>
    public async Task<int> ExecuteAsync(string scriptName, object? parameters = null)
    {
        var payload = new SystemRequestPayload
        {
            ScriptName = scriptName,
            Parameters = parameters is null ? null : JsonSerializer.SerializeToElement(parameters),
            RequestId = Guid.NewGuid().ToString()
        };

        var resp = await _http.PostAsJsonAsync("/api/system/execute", payload);
        resp.EnsureSuccessStatusCode();
        var result = await resp.Content.ReadFromJsonAsync<SystemExecuteResult>();
        return result?.AffectedRows ?? 0;
    }

    /// <summary>POST /api/system/scalar — returns single value</summary>
    public async Task<T> ScalarAsync<T>(string scriptName, object? parameters = null)
    {
        var payload = new SystemRequestPayload
        {
            ScriptName = scriptName,
            Parameters = parameters is null ? null : JsonSerializer.SerializeToElement(parameters),
            RequestId = Guid.NewGuid().ToString()
        };

        var resp = await _http.PostAsJsonAsync("/api/system/scalar", payload);
        resp.EnsureSuccessStatusCode();
        var result = await resp.Content.ReadFromJsonAsync<SystemScalarResult<T>>();
        return result!.Value;
    }
}

// ---------- Wire models ----------

public class SystemRequestPayload
{
    public string ScriptName { get; set; } = "";
    public JsonElement? Parameters { get; set; }
    public string RequestId { get; set; } = "";
    public string? Schema { get; set; }   // optional: project schema name
}

public class SystemQueryResult<T>
{
    public List<T> Data { get; set; } = new();
    public int TotalCount { get; set; }
    public string? RequestId { get; set; }
}

public class SystemExecuteResult
{
    public int AffectedRows { get; set; }
    public string? RequestId { get; set; }
}

public class SystemScalarResult<T>
{
    public T? Value { get; set; }
    public string? RequestId { get; set; }
}