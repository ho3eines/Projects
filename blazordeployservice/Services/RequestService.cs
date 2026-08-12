using BlazorDeployService.Models;
using BlazorDeployService.Services;
using Microsoft.Extensions.Options;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using System.Data;
using System.Net.Http.Json;

namespace BlazorDeployService.Services
{
    public interface IRequestService
    {
        string APIKey { get; set; }
        string BaseUrl { get; set; }

        Task<List<T>> GetData<T>(string sql, object parameters = null) where T : class;
        Task PrintToPdf(string reportPath, DataTable dt);
        Task<List<T>?> Request<T>(string sqlstr, object? param = null, bool isExec = false, string? connectionstring = null, string userCode = "") where T : class;
    }

    public partial class RequestService : IRequestService
    {
        readonly private HttpClient _http;
        readonly private IJSRuntime _js;
        readonly private IEncryptionService _enc;
        private string _token;
        public string APIKey { get; set; }
        public string BaseUrl { set; get; }
        private readonly AppSettings _appSettings;
        private readonly IAlertService _alertService;
        private readonly string _encryption;
        private readonly string _connectionstringToken;
        private readonly string _protocol;
        private readonly string _projectGuid;
        private string? _sessionToken;
        private string? _sessionEncKey;
        private DateTime _sessionExpiresUtc = DateTime.MinValue;

        public RequestService(HttpClient http, IJSRuntime js, IEncryptionService enc, IOptions<AppSettings> appSettings, IAlertService alertService)
        {
            _http = http;
            _js = js;
            _enc = enc;
            _alertService = alertService;
            _appSettings = appSettings.Value;
            BaseUrl = _appSettings.ApiSettings.BaseUrl;
            APIKey = _appSettings.ApiSettings.APIKey;
            _encryption = _appSettings.ApiSettings.Encryption;
            _connectionstringToken = _appSettings.ApiSettings.ConnectionStringToken;
            _protocol = _appSettings.ApiSettings.Protocol ?? "BlazorDeploy";
            _projectGuid = _appSettings.ApiSettings.ProjectGuid ?? "";
        }

        private bool IsHermes => string.Equals(_protocol, "Hermes", StringComparison.OrdinalIgnoreCase);

        //private async Task<DataTable?> RequestDataTable(string _query, bool exec = false)
        //{
        //    if (string.IsNullOrEmpty(_token))
        //        _token = await GetToken();

        //    try
        //    {

        //        Request Value = new Request
        //        {
        //            Token = _token,
        //            Data = _query,
        //            RequestDate = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
        //            Exec = exec,
        //            userCode = ""
        //        };
        //        //Console.WriteLine(_query);
        //        //_response Value = new _response(token: _token, data: _query, requestDate: DateTime.Now.ToString());
        //        string ValueJson = System.Text.Json.JsonSerializer.Serialize(Value);

        //        string encRequest = await _enc.EncryptDataAsync(ValueJson, _token);

        //        DataDto _datarequst = new DataDto
        //        {
        //            data = encRequest
        //        };

        //        var response = await _http.PostAsJsonAsync(BaseUrl + "Data/", _datarequst);
        //        if (response.IsSuccessStatusCode)
        //        {
        //            if (!exec)
        //            {
        //                string responseData = await response.Content.ReadAsStringAsync();
        //                var decData = await _enc.DecryptDataAsync(responseData, _token);
        //                //var decData = await _js.InvokeAsync<string>("decryptData", responseData, _token);
        //                RequestDataTable? _data = JsonConvert.DeserializeObject<RequestDataTable>(decData);
        //                return _data.Data;
        //            }
        //            return null;
        //        }
        //        else
        //        {
        //            dynamic responseData = await response.Content.ReadAsStringAsync();
        //            await _alertService.ShowErrorAsync("خطا", responseData.message ?? "");
        //            return null;
        //        }
        //    }
        //    catch (Exception ex)
        //    {
        //        await _alertService.ShowErrorAsync("خطا", ex.Message);
        //        return null;
        //    }
        //}
        //public async Task<string> GetToken()
        //{
        //    try
        //    {
        //        var _res = await _http.GetStringAsync(BaseUrl + "Data/");
        //        var decryptedData = await _enc.DecryptDataAsync(_res, "vqmx70HjZd4kz2qIEegN/pWlR+66QASRFuiJZTDgmOk=");
        //        //var decryptedData = await _js.InvokeAsync<string>("decryptData", _res, "vqmx70HjZd4kz2qIEegN/pWlR+66QASRFuiJZTDgmOk=");
        //        Request _request = JsonConvert.DeserializeObject<Request>(decryptedData);
        //        return _request.Data;
        //    }
        //    catch (Exception ex)
        //    {
        //        await _alertService.ShowErrorAsync("خطا در گرفتن توکن", ex.Message);
        //        return "";
        //    }
        //}
        private async Task<(string, string)> verifyAsync()
        {
            try
            {
                // پاکسازی و تنظیم هدرها
                _http.DefaultRequestHeaders.Clear();
                _http.DefaultRequestHeaders.Add("X-API-Key", APIKey);

                // ارسال درخواست
                var response = await _http.GetAsync(BaseUrl + "Data/");

                // خواندن پاسخ
                var responseString = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    var res = JsonConvert.DeserializeObject<dynamic>(responseString);

                    if (res == null)
                    {
                        await _alertService.ShowErrorAsync("خطا", "خطا در دریافت اطلاعات");
                        return (null, null);
                    }

                    int code = (int)res.code;
                    if (code == 200)
                    {
                        string encryptedData = (string)res.data;

                        if (string.IsNullOrEmpty(encryptedData))
                        {
                            await _alertService.ShowErrorAsync("خطا", "داده‌ای برای رمزگشایی وجود ندارد");
                            return (null, null);
                        }

                        // رمزگشایی داده‌ها
                        var decryptedData = await _enc.DecryptDataAsync(encryptedData, _encryption);

                        if (string.IsNullOrEmpty(decryptedData))
                        {
                            await _alertService.ShowErrorAsync("خطا", "خطا در رمزگشایی داده‌ها");
                            return (null, null);
                        }

                        var data = JsonConvert.DeserializeObject<dynamic>(decryptedData);

                        if (data == null)
                        {
                            await _alertService.ShowErrorAsync("خطا", "اطلاعاتی یافت نشد");
                            return (null, null);
                        }


                        return ((string)data.RequestId, (string)data.EncryptionKey);

                    }
                    else
                    {
                        // خطای سرور (کد غیر 200)
                        string message = (string)res.message ?? "خطای نامشخص";
                        await _alertService.ShowErrorAsync($"خطا {code}", message);
                        return (null, null);
                    }
                }
                else
                {
                    try
                    {
                        var errorRes = JsonConvert.DeserializeObject<dynamic>(responseString);
                        if (errorRes != null)
                        {
                            int errorCode = (int?)errorRes.code ?? (int)response.StatusCode;
                            string errorMessage = (string)errorRes.message ?? response.ReasonPhrase ?? "خطا در ارتباط با سرور";
                            await _alertService.ShowErrorAsync($"خطا {errorCode}", errorMessage);
                        }
                        else
                        {
                            await _alertService.ShowErrorAsync($"خطا {(int)response.StatusCode}", response.ReasonPhrase ?? "خطا در ارتباط با سرور");
                        }
                    }
                    catch
                    {
                        await _alertService.ShowErrorAsync($"خطا {(int)response.StatusCode}", response.ReasonPhrase ?? "خطا در ارتباط با سرور");
                    }
                    return (null, null);
                }
            }
            catch (HttpRequestException httpEx)
            {
                await _alertService.ShowErrorAsync("خطا در ارتباط با سرور", httpEx.Message);
                return (null, null);
            }
            catch (JsonException jsonEx)
            {
                await _alertService.ShowErrorAsync("خطا در پردازش اطلاعات", jsonEx.Message);
                return (null, null);
            }
            catch (Exception ex)
            {
                await _alertService.ShowErrorAsync("خطا در Verify", ex.Message);
                return (null, null);
            }
        }

        private async Task<List<T>?> Requestsever<T>(string _requestToken, string _encryptionKey, string _connectionStringToken, string _sqlstr, object? param = null, bool _isExec = false, string _userCode = "") where T : class
        {
            try
            {
                var _data = new requestdata
                {
                    token = Guid.NewGuid().ToString(),
                    requestDate = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                    connectionString = _connectionStringToken,
                    IsExec = _isExec,
                    SqlStr = _sqlstr,
                    Parameters = param,
                    userCode = _userCode,
                    ExpairDate = DateTime.Now.AddDays(1).ToString("yyyy-MM-dd HH:mm:ss"),
                    token2 = Guid.NewGuid().ToString()
                };

                string ValueJson = JsonConvert.SerializeObject(_data);

                string encdata = await _enc.EncryptDataAsync(ValueJson, _encryptionKey);

                _http.DefaultRequestHeaders.Clear();
                _http.DefaultRequestHeaders.Add("X-API-Key", _requestToken);

                var response = await _http.PostAsJsonAsync(BaseUrl + "Data/", encdata);

                if (response.IsSuccessStatusCode)
                {
                    string responseData = await response.Content.ReadAsStringAsync();
                    responeData res = JsonConvert.DeserializeObject<responeData>(responseData);
                    if (res is null) return null;
                    if (res.code == 200)
                    {
                        encdata = res.data;
                        if (!_data.IsExec)
                        {
                            //string decryptedData = await _enc.DecryptDataAsync(encdata, _encryptionKey);
                            //ResponseData data = JsonConvert.DeserializeObject<ResponseData>(encdata);

                            if (encdata is not null)
                            {
                                //string decList = await _enc.DecryptDataAsync(data.Data, _encryptionKey);
                                var obj = JsonConvert.DeserializeObject<List<T>>(encdata);
                                return obj;
                            }
                        }
                        else
                            return null;

                    }
                    else
                    {
                        await _alertService.ShowErrorAsync("خطا", res.message ?? "");
                        return null;
                    }
                }
                else
                {
                    dynamic responseData = await response.Content.ReadAsStringAsync();
                    await _alertService.ShowErrorAsync("خطا", responseData.message ?? "");
                    return null;
                }
            }
            catch (Exception ex)
            {
                await _alertService.ShowErrorAsync("خطا در ارسال به سرور", ex.Message);
                return null;
            }
            return null;
        }

        /// <summary>
        /// Hermes: named TSQL script (handshake with ProjectGuid first).
        /// BlazorDeploy: legacy raw SQL path.
        /// </summary>
        public async Task<List<T>?> Request<T>(string sqlstr, object? param = null, bool isExec = false, string? connectionstring = null, string userCode = "") where T : class
        {
            try
            {
                if (IsHermes)
                    return await HermesRequest<T>(sqlstr, param, isExec, isScalar: false, userCode, allowRetry: true);

                if (string.IsNullOrEmpty(connectionstring))
                    connectionstring = _connectionstringToken;

                (string RequestId, string EncryptionKey) = await verifyAsync();
                if (RequestId is not null)
                {
                    var r = await Requestsever<T>(RequestId, EncryptionKey, connectionstring, sqlstr, param, isExec, userCode);

                    if (isExec)
                        return null;
                    else
                        return r;


                }
                return null;
            }
            catch (Exception ex)
            {
                await _alertService.ShowErrorAsync("خطا در ارسال درخواست", ex.Message);
                return null;
            }
        }
        //private async Task<List<T>?> Request<T>(string connectionStringToken, string sqlstr, object? param = null, bool isExec = false, string userCode = "") where T : new()
        //{
        //    try
        //    {
        //        (string RequestId, string EncryptionKey) = await verifyAsync();
        //        if (RequestId is not null)
        //        {
        //            DataTable data = await Requestsever(RequestId, EncryptionKey, connectionStringToken, sqlstr, param, isExec, userCode);

        //            if (data is not null)
        //                return DataTableToList<T>(data);
        //            else
        //                return null;

        //        }
        //        return null;
        //    }
        //    catch (Exception ex)
        //    {
        //        await _alertService.ShowErrorAsync("خطا در ارسال درخواست", ex.Message);
        //        return null;
        //    }
        //}
        //
        //private List<T> DataTableToList<T>(DataTable dataTable) where T : new()
        //{
        //    var list = new List<T>();
        //    var properties = typeof(T).GetProperties();

        //    foreach (DataRow row in dataTable.Rows)
        //    {
        //        var item = new T();
        //        foreach (var property in properties)
        //        {
        //            if (dataTable.Columns.Contains(property.Name))
        //            {
        //                var value = row[property.Name];
        //                if (value != DBNull.Value)
        //                {
        //                    try
        //                    {
        //                        property.SetValue(item, Convert.ChangeType(value, property.PropertyType));
        //                    }
        //                    catch
        //                    {
        //                        // Ignore conversion errors
        //                    }
        //                }
        //            }
        //        }
        //        list.Add(item);
        //    }

        //    return list;
        //}

        /// <summary>
        /// این سرویس برای خواندن دیتا ها بر اساس مدل درخواستی، مورد استفاده قرار میگیرد
        /// </summary>
        public async Task<List<T>> GetData<T>(string sql, object parameters = null) where T : class
        {
            if (IsHermes)
                return await HermesRequest<T>(sql, parameters, isExec: false, isScalar: false, allowRetry: true) ?? new List<T>();

            (string RequestId, string EncryptionKey) = await verifyAsync();

            if (RequestId is not null)
            {
                var data = await Requestsever<T>(
                    RequestId,
                    EncryptionKey,
                    _connectionstringToken,
                    sql,
                    parameters
                );

                if (data is not null)
                {
                    var json = JsonConvert.SerializeObject(data);

                    return JsonConvert.DeserializeObject<List<T>>(json) ?? new List<T>();
                }
            }

            return new List<T>();
        }

        /// <summary>
        /// این سرویس برای نمایش ریپورت مورد استفاده قرار میگیرد
        /// </summary>
        public async Task PrintToPdf(string reportPath, DataTable dt)
        {
            try
            {
                ReportDto _report = new ReportDto
                {
                    ReportPath = reportPath,
                    dt = dt,
                    dateTime = DateTime.Now,
                    UserCode = ""
                };

                string ValueJson = JsonConvert.SerializeObject(_report);

                string encRequest = await _enc.EncryptDataAsync(ValueJson, "qwzxcvsdfgx70HjZd4xcrhxhr66QRFuiJZTDgmOk=");
                //string encRequest = await _js.InvokeAsync<string>("encryptData", ValueJson, "qwzxcvsdfgx70HjZd4xcrhxhr66QRFuiJZTDgmOk=");

                string responseData = "";

                var response = await _http.PostAsJsonAsync(BaseUrl + "report/pdf/", encRequest);
                if (response.IsSuccessStatusCode)
                {
                    responseData = await response.Content.ReadAsStringAsync();
                    await _js.InvokeVoidAsync("open", responseData, "_blank");
                }
                //var _res = await _http.GetStringAsync(_http.BaseAddress.ToString() + "report/pdf");
            }
            catch (Exception ex)
            {
                await _alertService.ShowErrorAsync("خطا در ساخت گزارش", ex.Message);
            }
        }
    }
    public class requestdata
    {
        public string token { set; get; }
        public string requestDate { set; get; }
        public string connectionString { set; get; }
        public bool IsExec { set; get; }
        public string SqlStr { set; get; }
        public object Parameters { set; get; }
        public string userCode { set; get; }
        public string ExpairDate { set; get; }
        public string token2 { set; get; }

    }

    public class ResponseData
    {
        public bool Success { set; get; }
        public string? Data { set; get; }
        public int? ResponseSize { set; get; }
        public string? ErrorMessage { set; get; }
    }

    public class dataReturn
    {
        public int code { set; get; }
        public List<dynamic> data { set; get; }
        public string message { set; get; }
    }
}
