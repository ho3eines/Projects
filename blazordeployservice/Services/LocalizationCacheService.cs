using BlazorDeployService.Helper;
using BlazorDeployService.Models; // اضافه کردن namespace مدل‌ها
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System;
using System.Collections.Concurrent;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace BlazorDeployService.Services
{
    public interface ILocalizationCacheService
    {
        int LangID { get; }

        event Action OnChange;

        bool AddSupportedLanguage(string code);
        Task GetLang();
        int GetLanguageIdByCode(string code);
        string GetLanguageTranslationValueByName(string Name);
        LocalizationSettings GetLocalizationSettings();
        List<string> GetSupportedLanguageCodes();
        string GetValue(string key);
        string? GetValueByCode(string Code, string columnName = "Name");
        Task InitializeAsync();
        void InsertLanguageTranslation(string Name);
        bool IsLanguageSupported(string code);
        Task RefreshCache();
        bool RemoveSupportedLanguage(string code);
        Task SetCurrentLanguage(string code);
        Task<DataTable?> SupportedLanguages();
        void UpdateSupportedLanguages(List<string> newSupportedCodes);
    }

    public class LocalizationCacheService : ILocalizationCacheService
    {
        private readonly IClientStorageService _clientstorage;
        private readonly IRequestService _req;
        private readonly AppSettings _appSettings; // استفاده از AppSettings

        private DataTable? _LangCache;
        private DataTable? _LanguageTranslationCache;
        private List<string> _supportedLanguageCodes;

        private const string CacheLang = "LangCache";
        private const string CacheLanguageTranslation = "LanguageTranslationCache";
        private const string CacheDateKey = "LangCacheDate";

        private static readonly ConcurrentDictionary<(int LangID, string Name), bool> _cache
            = new ConcurrentDictionary<(int, string), bool>();

        public event Action OnChange;
        public int LangID { get; private set; }

        // سازنده با IOptions
        public LocalizationCacheService(
            IRequestService req,
            IClientStorageService clientstorage,
            IOptions<AppSettings> appSettingsOptions) // استفاده از IOptions
        {
            _req = req;
            _clientstorage = clientstorage;
            _appSettings = appSettingsOptions.Value;
            _supportedLanguageCodes = _appSettings.Localization.SupportedLanguageCodes ?? new List<string>();
        }

        //// سازنده جایگزین برای تست یا موارد خاص
        //public LocalizationCacheService(
        //    RequestService req,
        //    IClientStorageService clientstorage,
        //    AppSettings appSettings) // بدون IOptions
        //{
        //    _req = req;
        //    _clientstorage = clientstorage;
        //    _appSettings = appSettings;
        //    _supportedLanguageCodes = _appSettings.Localization.SupportedLanguageCodes ?? new List<string>();
        //}

        public async Task InitializeAsync()
        {
            if (_LangCache is null)
            {
                try
                {
                    var cacheDate = await _clientstorage.GetLocalAsync<DateTime?>(CacheDateKey);
                    var cached = await _clientstorage.GetLocalAsync<string>(CacheLang);
                    var cacheData = await _clientstorage.GetLocalAsync<string>(CacheLanguageTranslation);

                    if (cacheDate != null && cached != null && (DateTime.Now - cacheDate.Value).TotalDays < 1)
                    {
                        // استفاده از کش موجود
                        _LangCache = JsonConvert.DeserializeObject<DataTable>(cached);
                        await GetLang();
                        _LanguageTranslationCache = JsonConvert.DeserializeObject<DataTable>(cacheData);
                    }
                    else
                    {
                        // خواندن از دیتابیس و ذخیره در کش
                        await LoadFromDatabase();
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"خطا در InitializeAsync: {ex.Message}");
                    // در صورت خطا، سعی کن از دیتابیس مستقیم بارگیری کنی
                    await LoadFromDatabase();
                }
            }
        }

        private async Task LoadFromDatabase()
        {
            //try
            //{
            //    var dt = await _req.Request(
            //        AppHelper.ConnectionStringToken,
            //        "SELECT ID, Code, Name, Flag FROM App.dbo.Language ORDER BY ID"
            //    );
            //    _LangCache = dt;

            //    await GetLang();

            //    var dtData = await _req.Request(
            //        "SELECT [Name],[Value] FROM [App].[dbo].[LanguageTranslation] where LangID=@LangID",
            //        new { LangID = LangID },false, AppHelper.ConnectionStringToken
            //    );
            //    _LanguageTranslationCache = dtData;

            //    // ذخیره در کش
            //    string data = JsonConvert.SerializeObject(dt);
            //    string data1 = JsonConvert.SerializeObject(dtData);

            //    await _clientstorage.SetLocalAsync(CacheLang, data);
            //    await _clientstorage.SetLocalAsync(CacheLanguageTranslation, data1);
            //    await _clientstorage.SetLocalAsync(CacheDateKey, DateTime.Now);
            //}
            //catch (Exception ex)
            //{
            //    Console.WriteLine($"خطا در LoadFromDatabase: {ex.Message}");
            //    throw;
            //}
        }

        public async Task RefreshCache()
        {
            await _clientstorage.RemoveLocalAsync(CacheLang);
            await _clientstorage.RemoveLocalAsync(CacheLanguageTranslation);
            await _clientstorage.RemoveLocalAsync(CacheDateKey);

            _LangCache = null;
            _LanguageTranslationCache = null;

            await InitializeAsync();
            NotifyStateChanged();
        }

        public async Task GetLang()
        {
            try
            {
                // اگر AutoDetection فعال باشد، از localStorage می‌خوانیم
                string preferredLang = _appSettings.Localization.DefaultLanguage;

                if (_appSettings.Localization.EnableAutoDetection)
                {
                    preferredLang = await _clientstorage.GetLocalAsync<string>("pref_culture")
                        ?? _appSettings.Localization.DefaultLanguage;
                }

                // بررسی آیا زبان انتخابی پشتیبانی می‌شود
                if (!IsLanguageSupported(preferredLang) && _supportedLanguageCodes.Any())
                {
                    preferredLang = _appSettings.Localization.DefaultLanguage;

                    // اگر زبان پیش‌فرض هم پشتیبانی نمی‌شود، اولین زبان پشتیبانی شده را انتخاب کن
                    if (!IsLanguageSupported(preferredLang))
                    {
                        preferredLang = _supportedLanguageCodes.First();
                    }
                }

                LangID = GetLanguageIdByCode(preferredLang);

                // ذخیره در localStorage برای استفاده بعدی
                if (_appSettings.Localization.EnableAutoDetection)
                {
                    await _clientstorage.SetLocalAsync("pref_culture", preferredLang);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"خطا در GetLang: {ex.Message}");
                LangID = 1; // مقدار پیش‌فرض
            }
        }

        public string? GetValueByCode(string Code, string columnName = "Name")
        {
            if (_LangCache == null) return "";
            var rows = _LangCache.Select($"Code = '{Code}'");
            if (rows.Length == 0) return "";
            return rows[0][columnName]?.ToString();
        }

        public async Task<DataTable?> SupportedLanguages()
        {
            await InitializeAsync();

            if (_LangCache == null)
                return null;

            // اگر لیست کدهای پشتیبانی شده خالی باشد، همه زبان‌ها را برگردان
            if (!_supportedLanguageCodes.Any())
            {
                return _LangCache;
            }

            // فیلتر کردن زبان‌ها بر اساس کدهای تنظیم شده
            var filteredRows = _LangCache.AsEnumerable()
                .Where(row => _supportedLanguageCodes.Contains(row.Field<string>("Code")))
                .ToList();

            if (filteredRows.Any())
            {
                var filteredTable = _LangCache.Clone();
                foreach (var row in filteredRows)
                {
                    filteredTable.ImportRow(row);
                }
                return filteredTable;
            }

            // اگر هیچ کدام از کدهای تنظیم شده در دیتابیس نبود، همه زبان‌ها را برگردان
            return _LangCache;
        }

        // متد برای دریافت فقط کدهای زبان پشتیبانی شده
        public List<string> GetSupportedLanguageCodes()
        {
            return _supportedLanguageCodes;
        }

        // متد برای بررسی آیا یک زبان خاص پشتیبانی می‌شود
        public bool IsLanguageSupported(string code)
        {
            // اگر لیست کدها خالی باشد، همه زبان‌ها پشتیبانی می‌شوند
            if (!_supportedLanguageCodes.Any())
                return true;

            return _supportedLanguageCodes.Contains(code);
        }

        public int GetLanguageIdByCode(string code)
        {
            try
            {
                if (_LangCache == null) return 1;

                // بررسی آیا کد در تنظیمات پشتیبانی می‌شود
                if (_supportedLanguageCodes.Any() && !_supportedLanguageCodes.Contains(code))
                {
                    // اگر کد پشتیبانی نمی‌شود، زبان پیش‌فرض یا اولین کد پشتیبانی شده را انتخاب کن
                    if (IsLanguageSupported(_appSettings.Localization.DefaultLanguage))
                    {
                        code = _appSettings.Localization.DefaultLanguage;
                    }
                    else if (_supportedLanguageCodes.Any())
                    {
                        code = _supportedLanguageCodes.First();
                    }
                    else
                    {
                        // اگر لیست خالی بود، اولین زبان از دیتابیس را انتخاب کن
                        var firstRow = _LangCache.Rows[0];
                        code = firstRow["Code"]?.ToString() ?? "fa-IR";
                    }
                }

                var rows = _LangCache.Select($"Code='{code}'");
                if (rows.Length == 0) return 1;
                return Int32.Parse(rows[0]["ID"]?.ToString() ?? "1");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"خطا در GetLanguageIdByCode: {ex.Message}");
                return 1;
            }
        }

        // متد برای تغییر پویای تنظیمات زبان
        public void UpdateSupportedLanguages(List<string> newSupportedCodes)
        {
            _supportedLanguageCodes = newSupportedCodes ?? new List<string>();
            NotifyStateChanged();
        }

        // متد برای افزودن یک زبان جدید
        public bool AddSupportedLanguage(string code)
        {
            if (string.IsNullOrEmpty(code) || _supportedLanguageCodes.Contains(code))
                return false;

            _supportedLanguageCodes.Add(code);
            NotifyStateChanged();
            return true;
        }

        // متد برای حذف یک زبان
        public bool RemoveSupportedLanguage(string code)
        {
            bool removed = _supportedLanguageCodes.Remove(code);
            if (removed)
            {
                NotifyStateChanged();
            }
            return removed;
        }

        // متد برای دریافت تنظیمات جاری
        public LocalizationSettings GetLocalizationSettings()
        {
            return _appSettings.Localization;
        }

        // متد برای تغییر زبان جاری
        public async Task SetCurrentLanguage(string code)
        {
            if (IsLanguageSupported(code))
            {
                await _clientstorage.SetLocalAsync("pref_culture", code);
                await GetLang(); // بارگیری مجدد با زبان جدید
                NotifyStateChanged();
            }
        }

        public string GetLanguageTranslationValueByName(string Name)
        {
            try
            {
                if (_LanguageTranslationCache == null)
                {
                    InsertLanguageTranslation(Name);
                    return Name;
                }
                var rows = _LanguageTranslationCache.Select($"Name='{Name}'");
                if (rows.Length == 0)
                {
                    InsertLanguageTranslation(Name);
                    return Name;
                }
                string? value = rows[0]["Value"]?.ToString();
                if (string.IsNullOrEmpty(value) || string.IsNullOrWhiteSpace(value))
                {
                    value = Name;
                }
                return value;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"خطا در GetLanguageTranslationValueByName: {ex.Message}");
                return Name;
            }
        }

        public void InsertLanguageTranslation(string Name)
        {
            //if (_cache.ContainsKey((LangID, Name)))
            //    return;

            //Task.Run(async () =>
            //{
            //    string sql = @"
            //        IF NOT EXISTS(SELECT TOP 1 1 FROM [App].[dbo].[LanguageTranslation] 
            //        WHERE LangID=@LangID AND Name=@Name)
            //        BEGIN
            //            INSERT [App].[dbo].[LanguageTranslation] (LangID,Name) 
            //            VALUES(@LangID,@Name)
            //        END";

            //    var param = new { LangID=LangID, Name=Name };
            //    await _req.Request( sql, param,true, AppHelper.ConnectionStringToken);
            //    _cache.TryAdd((LangID, Name), true);
            //}).Wait();
        }

        public string GetValue(string key)
        {
            return GetLanguageTranslationValueByName(key);
        }

        private void NotifyStateChanged() => OnChange?.Invoke();
    }
}