namespace Tarazin.Data;

/// <summary>
/// نتیجهٔ ایمن آزمون اتصال SQL برای صفحهٔ <c>/diag</c>.
/// هیچ نام سرور، دیتابیس، نسخه، مسیر فایل یا رشتهٔ اتصالی در نتیجه قرار نمی‌گیرد.
/// </summary>
/// <param name="Ok">آیا اتصال و اجرای <c>SELECT 1</c> موفق بود؟</param>
/// <param name="Message">پیام کنترل‌شدهٔ موفقیت یا خطا.</param>
/// <param name="Elapsed">مدت‌زمان آزمون.</param>
/// <param name="ProviderDescription">شرح غیرمحرمانهٔ ارائه‌دهندهٔ اتصال.</param>
public sealed record ConnectionCheckResult(
    bool Ok,
    string Message,
    TimeSpan Elapsed,
    string ProviderDescription);

/// <summary>اطلاعات داخلی مقصد دیتابیس برای اسکریپت‌های قدیمی تشخیصی.</summary>
public sealed class DatabaseStorageInfo
{
    public string ServerName { get; set; } = "";
    public string DatabaseName { get; set; } = "";
    public string DataFiles { get; set; } = "";
    public bool AccountingTablesReady { get; set; }
    public bool CurrencyTablesReady { get; set; }
    public long BaseDetilCount { get; set; }
    public long BaseDetilLinkCount { get; set; }
    public long PriceRateCount { get; set; }
    public long RateHistoryCount { get; set; }
}
