namespace Tarazin.Data;

/// <summary>
/// نتیجهٔ تست اتصال به SQL Server (خروجی <c>DbService.TestConnectionAsync</c>).
/// برای صفحهٔ عیب‌یابی <c>/diag</c> و لاگ راه‌اندازی استفاده می‌شود.
/// </summary>
/// <param name="Ok">آیا اتصال و اجرای <c>SELECT 1</c> موفق بود؟</param>
/// <param name="Message">پیام فارسی موفقیت یا علت خطا.</param>
/// <param name="Server">سروری که واقعاً به آن وصل شدیم.</param>
/// <param name="Database">دیتابیس فعال پس از اتصال.</param>
/// <param name="ServerVersion">خط اول <c>@@VERSION</c>.</param>
/// <param name="Elapsed">مدت‌زمان تست.</param>
/// <param name="MaskedConnectionString">رشتهٔ اتصال با رمز ماسک‌شده.</param>
public sealed record ConnectionCheckResult(
    bool Ok,
    string Message,
    string? Server,
    string? Database,
    string? ServerVersion,
    TimeSpan Elapsed,
    string MaskedConnectionString);

/// <summary>مقصد فیزیکی دیتابیس و چند شمارنده برای اثبات persistence.</summary>
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
