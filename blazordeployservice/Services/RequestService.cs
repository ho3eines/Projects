using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using BlazorDeployService.Helper;
using BlazorDeployService.Models;
using BlazorDeployService.Services;
using Microsoft.Extensions.Options;

namespace BlazorDeployService.Services
{
    #region ===================== PAYLOAD MODELS =====================

    /// <summary>توضیحات یک ستون برای ساخت خودکار جدول در سرور</summary>
    public sealed class SchemaColumnInfo
    {
        public string Name { get; set; } = default!;
        public string SqlType { get; set; } = "nvarchar(max)";
        public bool IsPrimaryKey { get; set; }
        public bool IsIdentity { get; set; }
        public bool IsRequired { get; set; }
        public string? DefaultExpression { get; set; }
    }

    /// <summary>اطلاعات مدل — کلاینت آن را از روی attribute ها استخراج می‌کند</summary>
    public sealed class ModelSchemaInfo
    {
        public string TypeName { get; set; } = default!;
        public string Schema { get; set; } = "dbo";
        public string Table { get; set; } = default!;
        public int TableVersion { get; set; }
        public List<SchemaColumnInfo> Columns { get; set; } = new();
    }

    /// <summary>پیلود استاندارد همه درخواست‌ها به webapi</summary>
    public sealed class DeployRequestPayload
    {
        public string Tsql { get; set; } = default!;
        public ModelSchemaInfo? Model { get; set; }
        public Dictionary<string, object?>? Parameters { get; set; }
        public string? ScriptName { get; set; }
        public Guid? CorrelationId { get; set; } = Guid.NewGuid();
        public Guid ProjectGuid { get; set; }
        public Guid? UserId { get; set; }
        public bool RequireUser { get; set; }
    }

    /// <summary>پاسخ استاندارد سرور</summary>
    public sealed class DeployResponse<T>
    {
        public Guid? CorrelationId { get; set; }
        public int TotalCount { get; set; }
        public T? Data { get; set; }
        public int AffectedRows { get; set; }
        public long DurationMs { get; set; }
        public string? Error { get; set; }
    }

    #endregion

    #region ===================== INTERFACE =====================

    /// <summary>
    /// سرویس مرکزی ارتباط با webapi — مدل‌محور، امن و خود-تشخیص‌دهنده schema
    /// </summary>
    public interface IRequestService
    {
        /// <summary>اجرای SELECT — نتیجه لیستی از مدل</summary>
        Task<List<T>> QueryAsync<T>(string tsql, object? parameters = null, Guid? userId = null, CancellationToken ct = default);

        /// <summary>اجرای SELECT با مدل به‌عنوان الگو (سرور جدول/ستون را خودکار می‌سازد)</summary>
        Task<List<T>> QueryModelAsync<T>(string tsql, T? model = null, Guid? userId = null, CancellationToken ct = default) where T : class;

        /// <summary>اجرای INSERT/UPDATE/DELETE/DDL — تعداد رکوردهای متأثر</summary>
        Task<int> ExecuteAsync(string tsql, object? parameters = null, Guid? userId = null, CancellationToken ct = default);

        /// <summary>اجرای INSERT با مدل — سرور جدول را مطمئن می‌کند سپس درج می‌کند</summary>
        Task<int> ExecuteModelAsync<T>(string tsql, T model, Guid? userId = null, CancellationToken ct = default) where T : class;

        /// <summary>اجرای اسکالر — یک مقدار</summary>
        Task<T?> ScalarAsync<T>(string tsql, object? parameters = null, Guid? userId = null, CancellationToken ct = default);

        /// <summary>اجرای اسکریپت نام‌دار از پوشه TSQL سرور</summary>
                Task<List<T>> RunScriptAsync<T>(string scriptName, object? parameters = null, Guid? userId = null, CancellationToken ct = default);

                /// <summary>BaseUrl تنظیم‌شده در appsettings — برای کامپوننت‌هایی مثل CKEditor</summary>
                string BaseUrl { get; }

                /// <summary>APIKey تنظیم‌شده در appsettings — برای کامپوننت‌هایی مثل CKEditor</summary>
                string APIKey { get; }

        // ===================== LEGACY API (Hermes v1 compatibility) =====================
        // Kept so existing clients (accounting, central-client, and the 7-product
        // clients) compile against the v2 transport. Implemented in RequestServiceCompat.cs.

        /// <summary>Legacy: named-script query or exec.</summary>
        Task<List<T>?> Request<T>(string scriptName, object? parameters = null, bool isExec = false,
            string? connectionstring = null, string userCode = "") where T : class;

        /// <summary>Legacy: named-script query (alias of RunScriptAsync).</summary>
        Task<List<T>> GetData<T>(string sql, object parameters = null) where T : class;

        /// <summary>Legacy no-op (PDF printing was client-side only).</summary>
        Task PrintToPdf(string reportPath, System.Data.DataTable dt);

        /// <summary>Legacy: stores a user/login token; also ends the session when null.</summary>
        void SetUserToken(string? token);

        /// <summary>Legacy: current session token (or stored token before login).</summary>
        string? UserToken { get; }

        /// <summary>Legacy: logs the current project in and returns a session-shaped result.</summary>
        Task<HermesLoginResult?> LoginAsync(string username, string password);
    }

    #endregion

    #region ===================== IMPLEMENTATION =====================

    /// <summary>
    /// پیاده‌سازی جدید RequestService — پروتکل امن v2:
    /// HMAC-SHA256 signature + Timestamp (ضد replay) + ProjectGuid + UserId اختیاری
    /// + ارسال ModelSchemaInfo برای ساخت خودکار جدول/ستون در سرور
    /// </summary>
    public sealed partial class RequestService : IRequestService
    {
        private readonly HttpClient _http;
                private readonly AppSettings _settings;
                private readonly IEncryptionService _encryption;
                private readonly IClientStorageService _storage;
                private readonly ISessionService _session;

                public string BaseUrl => ApiUrl.NormalizeBase(_settings.ApiSettings.BaseUrl);
                public string APIKey => _settings.ApiSettings.APIKey;

                public RequestService(
                    HttpClient http,
                    IOptions<AppSettings> settings,
                    IEncryptionService encryption,
                    IClientStorageService storage,
                    ISessionService session)
                {
                    _http = http;
                    _settings = settings.Value;
                    _encryption = encryption;
                    _storage = storage;
                    _session = session;

                    // اعمال مهلت درخواست تنظیم‌شده در appsettings
                    if (_settings.ApiSettings.Timeout > 0 &&
                        _http.Timeout != TimeSpan.FromMilliseconds(_settings.ApiSettings.Timeout))
                    {
                        _http.Timeout = TimeSpan.FromMilliseconds(_settings.ApiSettings.Timeout);
                    }
                }

        // ===================== PUBLIC API =====================

        public Task<List<T>> QueryAsync<T>(
            string tsql, object? parameters = null, Guid? userId = null, CancellationToken ct = default)
            => SendAsync<List<T>>("query", tsql, parameters, userId, model: null, ct: ct);

        public Task<List<T>> QueryModelAsync<T>(
            string tsql, T? model = null, Guid? userId = null, CancellationToken ct = default) where T : class
        {
            var (payload, schema) = BuildModelPayload(tsql, model, userId);
            return SendAsync<List<T>>("query", payload: payload, ct: ct);
        }

        public Task<int> ExecuteAsync(
            string tsql, object? parameters = null, Guid? userId = null, CancellationToken ct = default)
            => SendAsync<int>("execute", tsql, parameters, userId, model: null, ct: ct);

        public Task<int> ExecuteModelAsync<T>(
            string tsql, T model, Guid? userId = null, CancellationToken ct = default) where T : class
        {
            var (payload, schema) = BuildModelPayload(tsql, model, userId);
            return SendAsync<int>("execute", payload: payload, ct: ct);
        }

        public Task<T?> ScalarAsync<T>(
            string tsql, object? parameters = null, Guid? userId = null, CancellationToken ct = default)
            => SendAsync<T>("scalar", tsql, parameters, userId, model: null, ct: ct);

        public Task<List<T>> RunScriptAsync<T>(
            string scriptName, object? parameters = null, Guid? userId = null, CancellationToken ct = default)
            => SendAsync<List<T>>("script", scriptName, parameters, userId, model: null, ct: ct, isScript: true);

        // ===================== INTERNALS =====================

        private (DeployRequestPayload payload, ModelSchemaInfo? schema) BuildModelPayload<T>(
            string tsql, T? model, Guid? userId) where T : class
        {
            var schemaInfo = model is null ? null : SchemaReflector.Extract(model.GetType());
            var parameters = model is null ? null : ToDictionary(model);
            var payload = new DeployRequestPayload
            {
                Tsql = tsql,
                Model = schemaInfo,
                Parameters = parameters,
                ProjectGuid = ResolveProjectGuid(),
                UserId = userId,
                RequireUser = userId.HasValue
            };
            return (payload, schemaInfo);
        }

        private async Task<T> SendAsync<T>(
            string endpoint,
            string? tsql = null,
            object? parameters = null,
            Guid? userId = null,
            object? model = null,
            DeployRequestPayload? payload = null,
            CancellationToken ct = default,
            bool isScript = false)
        {
            payload ??= new DeployRequestPayload
            {
                Tsql = isScript ? null! : tsql!,
                ScriptName = isScript ? tsql : null,
                Model = model is null ? null : SchemaReflector.Extract(model.GetType()),
                Parameters = parameters is null ? null : ToDictionary(parameters),
                ProjectGuid = ResolveProjectGuid(),
                UserId = userId,
                RequireUser = userId.HasValue
            };

            // ۱) سریالایز
            var json = JsonSerializer.Serialize(payload, JsonOpts);

            // ۲) رمزنگاری اختیاری payload
                        var finalBody = _settings.Encryption.Enabled
                            ? await _encryption.EncryptDataAsync(json, _settings.Encryption.Key)
                            : json;

                        // ۳) ساخت هدرهای امنیتی
                        var headers = BuildSecurityHeaders(finalBody);

                        // ۴) ارسال — ساخت URL بدون اسلش تکراری
                        var url = ApiUrl.Combine(_settings.ApiSettings.BaseUrl, $"/api/request/{endpoint}");
                        using var request = new HttpRequestMessage(HttpMethod.Post, url)
                        {
                            Content = new StringContent(finalBody, Encoding.UTF8, _settings.Encryption.Enabled ? "text/plain" : "application/json")
                        };
            foreach (var (key, value) in headers)
                request.Headers.TryAddWithoutValidation(key, value);

            HttpResponseMessage response;
            try
            {
                response = await _http.SendAsync(request, ct);
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                throw new RequestServiceException(
                    "مهلت درخواست به پایان رسید — سرور پاسخ نداد. لطفاً دوباره تلاش کنید.", "TIMEOUT");
            }
            catch (HttpRequestException)
            {
                throw new RequestServiceException(
                    "اتصال به سرور برقرار نشد — وضعیت شبکه یا در دسترس بودن سرور را بررسی کنید.", "NETWORK");
            }

            using (response)
            {
                        var raw = await response.Content.ReadAsStringAsync(ct);

                        // نشست منقضی یا باطل → UI باید لاگین باز کند
                        if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized ||
                            response.StatusCode == System.Net.HttpStatusCode.Forbidden)
                        {
                            await _session.EndSessionAsync($"http-{(int)response.StatusCode}");
                            throw new RequestServiceException(
                                $"نشست شما منقضی شده است ({(int)response.StatusCode}) — لطفاً دوباره وارد شوید.",
                                "SESSION_EXPIRED");
                        }

                        if (!response.IsSuccessStatusCode)
                        {
                            throw new RequestServiceException(
                                $"درخواست ناموفق ({response.StatusCode}): {Truncate(raw, 400)}",
                                response.StatusCode.ToString());
                        }

                        var result = JsonSerializer.Deserialize<DeployResponse<T>>(raw, JsonOpts);
                        if (result is null)
                            throw new RequestServiceException("پاسخ سرور قابل خواندن نبود.", "EMPTY_RESPONSE");

                        if (!string.IsNullOrEmpty(result.Error))
                            throw new RequestServiceException(result.Error, "SERVER_ERROR");

                        // نشست زنده است — هر درخواست موفق زمان انقضا را جلو می‌برد
                        await _session.TouchAsync();

                        return result.Data!;
            }
        }

        /// <summary>
                /// هدرهای امنیتی: API-Key + Timestamp + HMAC-SHA256 امضای body + SessionToken + ProjectGuid
                /// </summary>
                private Dictionary<string, string> BuildSecurityHeaders(string body)
                {
                    var ts = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
                    var apiKey = _settings.ApiSettings.APIKey;
                    var secret = _settings.ApiSettings.ConnectionStringToken;

                    // امضا: HMAC-SHA256(secret, timestamp + body)
                    var signature = HmacSha256(secret, $"{ts}|{body}");

                    var headers = new Dictionary<string, string>
                    {
                        ["X-API-Key"] = apiKey,
                        ["X-Timestamp"] = ts,
                        ["X-Signature"] = signature,
                        ["X-Project-Guid"] = ResolveProjectGuid().ToString("D"),
                        ["X-User-Id"] = _session.ProjectGuid?.ToString("D") ?? ""
                    };

                    // توکن نشست — اگر نشست فعال باشد
                    if (!string.IsNullOrEmpty(_session.SessionToken))
                        headers["X-Auth-Token"] = _session.SessionToken;

                    return headers;
                }

        private Guid ResolveProjectGuid()
                {
                    // ۱) اول از appsettings — هر پروژه guid ثابت خودش را دارد
                    if (Guid.TryParse(_settings.ApiSettings.ProjectGuid, out var fromConfig))
                        return fromConfig;
                    // ۲) بعد از storage محلی (سازگاری با اجراهای قبلی)
                    var cached = _storage.GetLocalAsync<string>("hermes:project-guid").GetAwaiter().GetResult();
                    if (Guid.TryParse(cached, out var g)) return g;
                    var fresh = Guid.NewGuid();
                    _storage.SetLocalAsync("hermes:project-guid", fresh.ToString()).GetAwaiter().GetResult();
                    return fresh;
                }

        private static Dictionary<string, object?> ToDictionary(object model)
        {
            var dict = new Dictionary<string, object?>();
            foreach (var prop in model.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (prop.GetIndexParameters().Length == 0)
                    dict[prop.Name] = prop.GetValue(model);
            }
            return dict;
        }

        private static string HmacSha256(string secret, string data)
        {
            using var hmac = new System.Security.Cryptography.HMACSHA256(Encoding.UTF8.GetBytes(secret));
            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        private static string Truncate(string s, int max) => s.Length <= max ? s : s[..max] + "…";

        private static readonly JsonSerializerOptions JsonOpts = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };
    }

    /// <summary>استثنای اختصاصی سرویس درخواست</summary>
    public sealed class RequestServiceException : Exception
    {
        public string Code { get; }
        public RequestServiceException(string message, string code) : base(message) => Code = code;
    }

    #endregion

    #region ===================== SCHEMA REFLECTOR =====================

    /// <summary>
    /// متادیتای مدل را از روی attribute های SqlService استخراج می‌کند
    /// تا سرور بتواند جدول/ستون را بدون داشتن خود مدل بسازد
    /// </summary>
    public static class SchemaReflector
    {
        public static ModelSchemaInfo Extract(Type modelType)
        {
            var tableAttr = modelType.GetCustomAttribute<TableAttribute>();
            var info = new ModelSchemaInfo
            {
                TypeName = modelType.FullName ?? modelType.Name,
                Table = tableAttr?.Name ?? modelType.Name,
                TableVersion = tableAttr?.TableVersion ?? 0,
                Schema = "dbo"
            };

            foreach (var prop in modelType.GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (prop.GetIndexParameters().Length > 0) continue;

                var col = new SchemaColumnInfo
                {
                    Name = prop.Name,
                    IsPrimaryKey = prop.GetCustomAttribute<PrimaryKeyAttribute>() is not null,
                    IsIdentity = prop.GetCustomAttribute<IdentityAttribute>() is not null,
                    IsRequired = prop.GetCustomAttribute<RequiredAttribute>() is not null,
                    DefaultExpression = prop.GetCustomAttribute<DefaultAttribute>()?.Expression,
                    SqlType = prop.GetCustomAttribute<SqlTypeAttribute>()?.SqlType
                              ?? MapClrToSql(prop.PropertyType)
                };
                var maxLen = prop.GetCustomAttribute<MaxLengthAttribute>();
                if (maxLen is not null && col.SqlType.StartsWith("nvarchar"))
                    col.SqlType = $"nvarchar({maxLen.Length})";

                info.Columns.Add(col);
            }
            return info;
        }

        private static string MapClrToSql(Type type)
        {
            type = Nullable.GetUnderlyingType(type) ?? type;
            if (type == typeof(string)) return "nvarchar(max)";
            if (type == typeof(int)) return "int";
            if (type == typeof(long)) return "bigint";
            if (type == typeof(short)) return "smallint";
            if (type == typeof(byte)) return "tinyint";
            if (type == typeof(bool)) return "bit";
            if (type == typeof(decimal)) return "decimal(18,4)";
            if (type == typeof(double)) return "float";
            if (type == typeof(float)) return "real";
            if (type == typeof(Guid)) return "uniqueidentifier";
            if (type == typeof(DateTime)) return "datetime2";
            if (type == typeof(DateTimeOffset)) return "datetimeoffset";
            if (type == typeof(TimeSpan)) return "time";
            if (type.IsEnum) return "int";
            if (type == typeof(byte[])) return "varbinary(max)";
            return "nvarchar(max)";
        }
    }

    #endregion
}