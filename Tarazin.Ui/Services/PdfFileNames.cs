using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Tarazin.Services;

/// <summary>
/// ساخت نام فایل استاندارد فارسی برای خروجی‌های PDF.
///
/// قالب: «عنوان-شماره-تاریخ شمسی-اندازهٔ کاغذ.pdf» مثل:
///   فاکتور-GINV-00024-1405-06-05-A4.pdf
///   گزارش-چک‌ها-1405-06-05-A4.pdf
///
/// همهٔ نام‌ها از <see cref="Sanitize"/> عبور می‌کنند تا کاراکترهای نامعتبر
/// فایل‌سیستم (Windows: \ / : * ? " &lt; &gt; | و کنترل‌کاراکترها) حذف شوند.
/// </summary>
public static class PdfFileNames
{
    private static readonly PersianCalendar Pc = new();

    private static readonly char[] InvalidChars = Path.GetInvalidFileNameChars();

    /// <summary>
    /// تاریخ شمسی به‌صورت نام‌فایل‌پسند با رقم لاتین و صفر پیش‌رو:
    /// مثلاً 1405-06-05 (نه ۱۴۰۵-۶-۵) تا با همهٔ فایل‌سیستم‌ها سازگار باشد.
    /// </summary>
    public static string ShamsiDate(DateTime date)
    {
        var y = Pc.GetYear(date);
        var m = Pc.GetMonth(date);
        var d = Pc.GetDayOfMonth(date);
        return $"{y:D4}-{m:D2}-{d:D2}";
    }

    /// <summary>
    /// پاک‌سازی نام فایل: کاراکترهای نامعتبر و کنترل‌کاراکترها با «-» جایگزین،
    /// فاصله‌های تکراری و خط تیرهٔ تکراری جمع می‌شوند و نقطه/فاصله/خط تیرهٔ
    /// انتهایی حذف می‌شود (مشکل نام‌گذاری ویندوز).
    /// </summary>
    public static string Sanitize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return "سند";

        var sb = new StringBuilder(raw.Length);
        foreach (var ch in raw)
        {
            sb.Append(Array.IndexOf(InvalidChars, ch) >= 0 || char.IsControl(ch) ? '-' : ch);
        }

        var cleaned = Regex.Replace(sb.ToString(), @"\s+", " ");
        cleaned = Regex.Replace(cleaned, @"-{2,}", "-");
        cleaned = cleaned.Trim().Trim('.', '-', ' ');

        return string.IsNullOrWhiteSpace(cleaned) ? "سند" : cleaned;
    }

    /// <summary>نام فایل فاکتور خرید/فروش: فاکتور-{شماره}-{تاریخ شمسی}-{اندازه}.pdf</summary>
    public static string Invoice(string invoiceNumber, DateTime invoiceDate, string paperSize)
        => $"{Sanitize($"فاکتور-{invoiceNumber}")}-{ShamsiDate(invoiceDate)}-{paperSize}.pdf";

    /// <summary>نام فایل گزارش چک‌ها: گزارش-چک‌ها-{تاریخ شمسی}-{اندازه}.pdf</summary>
    public static string ChequeReport(DateTime date, string paperSize)
        => $"{Sanitize("گزارش-چک‌ها")}-{ShamsiDate(date)}-{paperSize}.pdf";

    /// <summary>نام فایل سند حسابداری: سند-{شماره}-{تاریخ شمسی}-{ساده/پیشرفته}-{اندازه}.pdf</summary>
    public static string Document(string documentNumber, bool advanced, DateTime date, string paperSize)
    {
        var kind = advanced ? "پیشرفته" : "ساده";
        return $"{Sanitize($"سند-{documentNumber}")}-{kind}-{ShamsiDate(date)}-{paperSize}.pdf";
    }
}
