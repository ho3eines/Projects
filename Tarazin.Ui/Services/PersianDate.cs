using System.Globalization;

namespace Tarazin.Services;

/// <summary>
/// کمک‌توابع تاریخ شمسی برای منطق سیستمیِ سال مالی.
/// تشخیص سال جاری و محاسبهٔ شروع/پایان آن بر اساس تقویم شمسی.
/// </summary>
public static class PersianDate
{
    private static readonly PersianCalendar Pc = new();

    /// <summary>سال شمسی جاری سیستم (مثلاً 1405).</summary>
    public static int CurrentYear => Pc.GetYear(DateTime.Today);

    /// <summary>ماه شمسی جاری سیستم (1 تا 12).</summary>
    public static int CurrentMonth => Pc.GetMonth(DateTime.Today);

    /// <summary>نمایش تاریخ میلادی به صورت شمسی (مثلاً 1405/06/06).</summary>
    public static string ToPersian(DateTime date)
        => $"{Pc.GetYear(date):0000}/{Pc.GetMonth(date):00}/{Pc.GetDayOfMonth(date):00}";

    /// <summary>روز شمسی جاری سیستم (1 تا 31).</summary>
    public static int CurrentDay => Pc.GetDayOfMonth(DateTime.Today);

    /// <summary>اولین روز سال شمسی.</summary>
    public static DateTime StartOfYear(int year) => Pc.ToDateTime(year, 1, 1, 0, 0, 0, 0);

    /// <summary>آخرین روز سال شمسی (29 یا 30 اسفند بسته به کبیسه).</summary>
    public static DateTime EndOfYear(int year)
    {
        var lastDay = Pc.IsLeapYear(year) ? 30 : 29;
        return Pc.ToDateTime(year, 12, lastDay, 0, 0, 0, 0);
    }

    /// <summary>نمایش متن سال شمسی (مثلاً «1405»).</summary>
    public static string YearName(int year) => year.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// بازهٔ میلادی یک دورهٔ شمسی به فرمت N'1405-06' (سال-ماه).
    /// از PersianCalendar دقیق استفاده می‌کند نه تقریب 621+.
    /// </summary>
    public static (DateTime From, DateTime To) RangeOfPeriod(string period)
    {
        var parts = (period ?? string.Empty).Trim().Split('-');
        if (parts.Length != 2
            || !int.TryParse(parts[0], out var year)
            || !int.TryParse(parts[1], out var month)
            || month < 1 || month > 12)
        {
            // Fallback: ماه جاری
            year = CurrentYear;
            month = CurrentMonth;
        }

        var from = Pc.ToDateTime(year, month, 1, 0, 0, 0, 0);
        var lastDay = month == 12 ? (Pc.IsLeapYear(year) ? 30 : 29) : (month <= 6 ? 31 : 30);
        var to = Pc.ToDateTime(year, month, lastDay, 23, 59, 59, 999);
        return (from, to);
    }
}
