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
}
