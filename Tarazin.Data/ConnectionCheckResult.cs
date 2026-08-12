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
