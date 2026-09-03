using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Tarazin.Components;

/// <summary>
/// پردازش متنِ ورودی عددی برای <see cref="TzNumericField{T}"/>:
/// نرمال‌سازی ارقام فارسی/عربی به ASCII، حذف جداکننده‌های گروهیِ تایپ‌شده،
/// تشخیص ممیز (نقطه / اسلش / «٫» بسته به فرهنگ جاری) و گروه‌بندی سه‌رقمیِ
/// بخش صحیح «در همان لحظهٔ تایپ».
/// عمداً مستقل از MudBlazor و Razor است تا بتوان برایش تست واحد نوشت.
/// </summary>
public static class TzNumericText
{
    private const string DisplayFormat = "#,##0.####";

    // جداکننده‌های گروهی که هنگام تایپ ممکن است وارد شوند — همه «حذف» می‌شوند
    // (به‌جز نویسه‌ای که فرهنگ جاری خودش ممیز می‌داند؛ در TryParse استثنا می‌خورد)
    private static readonly char[] BaseGroupSeparators =
    {
        ',', '،', '\u066C', ' ', '\u00A0', '\u202F', '\''
    };

    // جداکننده‌های اعشاریِ پذیرفته — اولین موردِ یافته ممیز در نظر گرفته می‌شود
    private static readonly char[] DecimalSeparators = { '.', '/', '\u066B', ',' };

    static TzNumericText()
    {
        // ویرگولِ ASCII در جایی که فرهنگِ جاری خودش از آن به‌عنوان ممیز استفاده
        // می‌کند (مثل fa-IR در برخی نسخه‌ها) نمی‌تواند «گروه‌بند» باشد.
        var dec = CultureInfo.CurrentCulture.NumberFormat.NumberDecimalSeparator;
        if (dec.Length == 1 && Array.IndexOf(DecimalSeparators, dec[0]) < 0)
            DecimalSeparators[0] = dec[0]; // مهم‌ترین ممیز، اول بررسی شود
    }

    /// <summary>ارقام فارسی/عربی را به ASCII تبدیل می‌کند.</summary>
    public static string NormalizeDigits(string input)
    {
        if (string.IsNullOrEmpty(input)) return input ?? string.Empty;
        var sb = new StringBuilder(input.Length);
        foreach (var ch in input)
        {
            if (ch is >= '\u06F0' and <= '\u06F9')          // ۰..۹
                sb.Append((char)(ch - '\u06F0' + '0'));
            else if (ch is >= '\u0660' and <= '\u0669')     // ٠..٩
                sb.Append((char)(ch - '\u0660' + '0'));
            else
                sb.Append(ch);
        }
        return sb.ToString();
    }

    /// <summary>
    /// متن تایپ‌شده را به عدد تبدیل می‌کند. <paramref name="canonical"/> نمایشِ
    /// نرمال‌شدهٔ همان ورودی است (گروه‌بندی سه‌رقمی بخش صحیح + حفظ ممیزِ انتهایی
    /// و ارقام اعشارِ تایپ‌شده) تا کاربر بتواند «12.» و «12.50» را آزادانه تایپ کند.
    /// </summary>
    public static bool TryParse(string? raw, CultureInfo culture,
                                out decimal value, out string canonical,
                                bool allowDecimal = true)
    {
        value = 0m;
        canonical = string.Empty;

        var s = NormalizeDigits(raw ?? string.Empty).Trim();
        if (s.Length == 0) return true; // خالی: خالی می‌ماند (فیلدهای nullable)

        // حذف جداکننده‌های گروهی — نویسهٔ ممیزِ فرهنگ جاری حذف نمی‌شود
        // (در برخی فرهنگ‌ها ویرگول ممیز است، نه گروه‌بند)
        var decSep = culture.NumberFormat.NumberDecimalSeparator;
        var decChar0 = decSep.Length == 1 ? decSep[0] : '\0';
        var sb = new StringBuilder(s.Length);
        foreach (var ch in s)
            if (ch == decChar0 || Array.IndexOf(BaseGroupSeparators, ch) < 0) sb.Append(ch);
        var cleaned = sb.ToString();

        // ممیز: اولین موردِ پذیرفته؛ مورد دوم یعنی ورودی نامعتبر —
        // به‌جز الگوی گروه‌بندی اروپایی مثل «1.250.000» که همهٔ جداکننده‌های
        // تکراری با گروه‌های دقیقاً سه‌رقمی، گروه‌بند هستند نه ممیز.
        int decPos = -1;
        for (int i = 0; i < cleaned.Length; i++)
        {
            var ch = cleaned[i];
            var isDec = (decSep.Length == 1 && ch == decSep[0]) ||
                        Array.IndexOf(DecimalSeparators, ch) >= 0;
            if (!isDec) continue;
            if (!allowDecimal) return false;    // T صحیح است → ممیز مجاز نیست
            if (decPos >= 0)
            {
                // جداکنندهٔ تکراری؟ فقط اگر الگوی 1-3 رقم + (جدا + 3 رقم)* باشد گروه‌بند است
                if (!IsEuropeanGrouping(cleaned)) return false; // دو ممیز → نامعتبر
                cleaned = Regex.Replace(cleaned, @"[.,\u060C\u066C\u066B](\d{3})(?!\d)", "$1");
                decPos = -1;
                i = -1; // اسکن از نو با متنِ پاک‌شده
                continue;
            }
            decPos = i;
        }

        var intPart = decPos >= 0 ? cleaned[..decPos] : cleaned;
        var fracPart = decPos >= 0 ? cleaned[(decPos + 1)..] : string.Empty;

        var negative = intPart.StartsWith('-');
        if (negative) intPart = intPart[1..];
        if (intPart.Length == 0 && fracPart.Length == 0) return false; // فقط ممیز یا فقط منفی

        if (intPart.Any(c => c is < '0' or > '9')) return false;
        if (fracPart.Any(c => c is < '0' or > '9')) return false;

        var invariant = (intPart.Length == 0 ? "0" : intPart) + "." + (fracPart.Length == 0 ? "0" : fracPart);
        if (!decimal.TryParse(invariant, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var parsed))
            return false;
        value = negative ? -parsed : parsed;

        // نمایش نرمال: گروه‌بندی بخش صحیح (همیشه بدون علامت؛ علامت جدا اضافه می‌شود)
        // + حفظِ «شکل در حال تایپ» بخش اعشار
        var unsignedInt = decimal.Parse(intPart.Length == 0 ? "0" : intPart, CultureInfo.InvariantCulture);
        canonical = (negative ? "-" : "") + Format(unsignedInt, culture);
        if (decPos >= 0)
            canonical += (decSep.Length == 1 ? decSep : ".") + fracPart;

        return true;
    }

    /// <summary>
    /// دلیلِ ردِ ورودی، برای نمایشِ خطای زیر فیلد (TzNumericField) — به‌جایِ اینکه
    /// ورودیِ نامعتبر بی‌صدا نگه داشته شود. فقط بعد از false شدنِ
    /// <see cref="TryParse"/> صدا بزنید. null یعنی ورودی معتبر است یا در
    /// «حالتِ میانیِ تایپ» قرار دارد (مثل «-» یا «.») که نباید خطا بگیرد.
    /// </summary>
    public static string? RejectionReason(string? raw, CultureInfo culture, bool allowDecimal)
    {
        var s = NormalizeDigits(raw ?? string.Empty).Trim();
        if (s.Length == 0 || !s.Any(c => c is >= '0' and <= '9'))
            return null; // خالی یا میانی (مثل «-» تنها) → خطا نشان داده نشود

        var decSep = culture.NumberFormat.NumberDecimalSeparator;

        bool IsDecSep(char ch) =>
            (decSep.Length == 1 && ch == decSep[0]) ||
            Array.IndexOf(DecimalSeparators, ch) >= 0;

        // جداکننده‌های گروهیِ تایپ‌شده (ویرگول و…) مثل TryParse حذف می‌شوند
        var decChar0 = decSep.Length == 1 ? decSep[0] : '\0';
        var sb = new StringBuilder(s.Length);
        foreach (var ch in s)
            if (ch == decChar0 || Array.IndexOf(BaseGroupSeparators, ch) < 0) sb.Append(ch);
        var cleaned = sb.ToString();

        if (!allowDecimal && cleaned.Any(IsDecSep))
            return "در این فیلد فقط عدد صحیح مجاز است.";

        if (cleaned.Count(IsDecSep) > 1)
            return "ممیز تکراری — فقط یک ممیز مجاز است.";

        // منهای فقط یک‌بار و در ابتدا
        var digitsPart = cleaned.StartsWith('-') ? cleaned[1..] : cleaned;
        if (digitsPart.Contains('-'))
            return "فقط ارقام، ممیز و جداکنندهٔ گروه مجاز است.";

        foreach (var ch in digitsPart)
        {
            if (ch is >= '0' and <= '9' || IsDecSep(ch)) continue;
            return "فقط ارقام، ممیز و جداکنندهٔ گروه مجاز است.";
        }

        // شکل درست است ولی خارج از دامنهٔ decimal (سرریز)
        return "عدد واردشده بیش از حد بزرگ است.";
    }

    /// <summary>قالب نمایش استاندارد: گروه‌بندی سه‌رقمی، حداکثر چهار رقم اعشار.</summary>
    public static string Format(decimal value, CultureInfo culture)
        => value.ToString(DisplayFormat, culture);

    // ── نمایش سلول‌های جدول: همان سبک TzNumericField، با فرهنگ جاری ────────────
    // برای سلول‌های فقط‌خواندنیِ جداول (TzDataTable/MudTable) از همین overloadها
    // استفاده کنید، نه ToString("N0")/("N2") ثابت: هیچ ارقامِ اعشاری‌ای بی‌صدا
    // گرد یا صفرچسبانی نمی‌شود و نمایش دقیقاً با فیلدِ عددیِ فرم‌ها یکی می‌شود.
    // null → رشتهٔ خالی (مثل `?.ToString()` قبلی).

    /// <summary>نمایش با فرهنگ جاری (معادل <see cref="Format(decimal, CultureInfo)"/>).</summary>
    public static string Format(decimal value)
        => Format(value, CultureInfo.CurrentCulture);

    /// <summary>نمایش مقدار nullable؛ null → رشتهٔ خالی.</summary>
    public static string Format(decimal? value)
        => value.HasValue ? Format(value.Value) : string.Empty;

    /// <summary>نمایش با فرهنگ صریح؛ null → رشتهٔ خالی.</summary>
    public static string Format(decimal? value, CultureInfo culture)
        => value.HasValue ? Format(value.Value, culture) : string.Empty;

    /// <summary>نمایش double (گروه‌بندی + حداکثر چهار رقم اعشار).</summary>
    public static string Format(double value)
        => value.ToString(DisplayFormat, CultureInfo.CurrentCulture);

    public static string Format(double? value)
        => value.HasValue ? Format(value.Value) : string.Empty;

    public static string Format(double value, CultureInfo culture)
        => value.ToString(DisplayFormat, culture);

    public static string Format(double? value, CultureInfo culture)
        => value.HasValue ? Format(value.Value, culture) : string.Empty;

    /// <summary>نمایش عدد صحیحِ بزرگ با گروه‌بندی (شمارنده‌ها، تعداد ردیف‌ها).</summary>
    public static string Format(int value)
        => value.ToString("#,##0", CultureInfo.CurrentCulture);

    public static string Format(int? value)
        => value.HasValue ? Format(value.Value) : string.Empty;

    public static string Format(int value, CultureInfo culture)
        => value.ToString("#,##0", culture);

    public static string Format(int? value, CultureInfo culture)
        => value.HasValue ? Format(value.Value, culture) : string.Empty;

    public static string Format(long value)
        => value.ToString("#,##0", CultureInfo.CurrentCulture);

    public static string Format(long? value)
        => value.HasValue ? Format(value.Value) : string.Empty;

    public static string Format(long value, CultureInfo culture)
        => value.ToString("#,##0", culture);

    public static string Format(long? value, CultureInfo culture)
        => value.HasValue ? Format(value.Value, culture) : string.Empty;

    /// <summary>
    /// الگوی گروه‌بندی اروپایی/فارسیِ چسبیده: «1.250.000» یا «1٬250٬000» —
    /// یک تا سه رقمِ آغازین و بعد گروه‌های دقیقاً سه‌رقمی با جداکنندهٔ یکسان.
    /// </summary>
    private static bool IsEuropeanGrouping(string s)
        => Regex.IsMatch(s, @"^\d{1,3}([.,\u060C\u066C\u066B]\d{3})+$");
}
