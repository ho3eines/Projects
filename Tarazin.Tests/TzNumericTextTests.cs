using System.Globalization;
using Tarazin.Components;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// تست‌های پردازش متنِ فیلد عددی ترازین (TzNumericText) —
/// پشتوانهٔ «جداکنندهٔ سه‌رقمی runtime» در TzNumericField.
/// همهٔ تست‌ها با فرهنگ invariant اجرا می‌شوند تا قطعی باشند؛
/// نرمال‌سازی ارقام و پذیرش ممیزهای چندگانه مستقل از فرهنگ است.
/// </summary>
public class TzNumericTextTests
{
    private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;
    private static readonly CultureInfo Fa = CultureInfo.GetCultureInfo("fa-IR");

    private static (bool Ok, decimal Value, string Canonical) Parse(
        string input, CultureInfo? culture = null, bool allowDecimal = true)
    {
        culture ??= Inv;
        var ok = TzNumericText.TryParse(input, culture, out var v, out var c, allowDecimal);
        return (ok, v, c);
    }

    // ── گروه‌بندی سه‌رقمی حین تایپ ────────────────────────────────

    [Theory]
    [InlineData("1250000", "1,250,000")]
    [InlineData("12500000", "12,500,000")]
    [InlineData("100", "100")]
    [InlineData("1000", "1,000")]
    [InlineData("999", "999")]
    [InlineData("1000000000", "1,000,000,000")]
    public void Grouping_Applied_While_Typing(string input, string expected)
    {
        var r = Parse(input);
        Assert.True(r.Ok);
        Assert.Equal(expected, r.Canonical);
    }

    [Fact]
    public void Typing_Char_By_Char_Gives_Growing_Grouped_Text()
    {
        // شبیه‌سازی تایپ تدریجی کاربر
        var acc = "";
        var expected = new[] { "1", "12", "125", "1,250", "12,50", "125,000", "1,250,000" };
        // 12,50 → 125,000: کاربر بین 12,50 و 125,000 رقم می‌گذارد
        Assert.Equal(expected[0], Parse("1").Canonical);
        Assert.Equal(expected[1], Parse("12").Canonical);
        Assert.Equal(expected[2], Parse("125").Canonical);
        Assert.Equal(expected[3], Parse("1250").Canonical);
        Assert.Equal(expected[5], Parse("125000").Canonical);
        Assert.Equal(expected[6], Parse("1250000").Canonical);
    }

    // ── ارقام فارسی/عربی ─────────────────────────────────────────

    [Theory]
    [InlineData("۱۲۳۴۵۶۷", "1,234,567", 1234567)]
    [InlineData("١٢٣٤٥٦٧", "1,234,567", 1234567)] // ارقام عربی
    [InlineData("۱٬۲۳۴٬۵۶۷", "1,234,567", 1234567)] // با جداکنندهٔ فارسی
    public void Persian_Arabic_Digits_Normalized(string input, string expectedCanonical, decimal expectedValue)
    {
        var r = Parse(input);
        Assert.True(r.Ok);
        Assert.Equal(expectedCanonical, r.Canonical);
        Assert.Equal(expectedValue, r.Value);
    }

    // ── ورودی‌های با جداکنندهٔ تایپ‌شده ───────────────────────────

    [Theory]
    [InlineData("1,250,000", 1250000)]
    [InlineData("1 250 000", 1250000)]
    [InlineData("1.250.000", 1250000)] // کاربر گروه‌بند را نقطه زده
    public void Pasted_Formatted_Input_Parses(string input, decimal expected)
    {
        var r = Parse(input);
        Assert.True(r.Ok);
        Assert.Equal(expected, r.Value);
    }

    // ── ممیز اعشار ───────────────────────────────────────────────

    [Theory]
    [InlineData("12.5", 12.5, "12.5")]
    [InlineData("12/5", 12.5, "12.5")]      // اسلش = ممیز (کیبورد فارسی)
    [InlineData("12.50", 12.5, "12.50")]    // شکل تایپ‌شده حفظ شود
    [InlineData("12.", 12, "12.")]
    [InlineData(".5", 0.5, "0.5")]
    [InlineData("0.0001", 0.0001, "0.0001")]
    public void Decimal_Input_Keeps_Typing_Shape(string input, decimal expectedValue, string expectedCanonical)
    {
        var r = Parse(input);
        Assert.True(r.Ok);
        Assert.Equal(expectedValue, r.Value);
        Assert.Equal(expectedCanonical, r.Canonical);
    }

    [Theory]
    [InlineData("1.2.3")]
    [InlineData("12..5")]
    [InlineData("abc")]
    [InlineData("12a")]
    [InlineData("-")]
    [InlineData("--5")]
    public void Invalid_Input_Rejected(string input)
    {
        Assert.False(Parse(input).Ok);
    }

    [Fact]
    public void Decimal_Point_Rejected_When_Integer_Only()
    {
        Assert.False(Parse("12.5", allowDecimal: false).Ok);
        Assert.True(Parse("12", allowDecimal: false).Ok);
    }

    // ── منفی ─────────────────────────────────────────────────────

    [Theory]
    [InlineData("-1250", -1250, "-1,250")]
    [InlineData("-1250.75", -1250.75, "-1,250.75")]
    public void Negative_Numbers_Parses(string input, decimal expectedValue, string expectedCanonical)
    {
        var r = Parse(input);
        Assert.True(r.Ok);
        Assert.Equal(expectedValue, r.Value);
        Assert.Equal(expectedCanonical, r.Canonical);
    }

    // ── خالی ─────────────────────────────────────────────────────

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Empty_Input_Is_Valid_Empty(string input)
    {
        var r = Parse(input);
        Assert.True(r.Ok);
        Assert.Equal(0m, r.Value);
        Assert.Equal("", r.Canonical);
    }

    // ── فرهنگ fa-IR ──────────────────────────────────────────────

    [Fact]
    public void FaCulture_Canonical_Uses_NonAscii_Separators()
    {
        var r = Parse("1250000", Fa);
        Assert.True(r.Ok);
        Assert.Equal(1250000m, r.Value);
        // fa-IR جداکننده‌های غیر ASCII دارد؛ فقط مطمئن می‌شویم گروه‌بندی اعمال شده
        Assert.Matches(@"^1\D{1,2}250\D{1,2}000$", r.Canonical);
    }

    // ── Format ───────────────────────────────────────────────────

    [Fact]
    public void Format_Uses_Grouping_And_Upto_Four_Decimals()
    {
        Assert.Equal("1,250,000", TzNumericText.Format(1250000m, Inv));
        Assert.Equal("12.5", TzNumericText.Format(12.50m, Inv));
        Assert.Equal("0.0001", TzNumericText.Format(0.0001m, Inv));
    }

    // ── نمایش سلول‌های جدول (overloadهای culture-less و انواع دیگر) ─────

    [Fact]
    public void Format_CultureLess_Matches_Current_Culture()
    {
        // overload بدون فرهنگ = همان Format با CultureInfo.CurrentCulture
        Assert.Equal(TzNumericText.Format(1250.75m, CultureInfo.CurrentCulture),
                     TzNumericText.Format(1250.75m));
        Assert.Equal(TzNumericText.Format(1250.75, CultureInfo.CurrentCulture),
                     TzNumericText.Format(1250.75));
    }

    [Fact]
    public void Format_Nullable_Returns_Empty_For_Null()
    {
        Assert.Equal("", TzNumericText.Format((decimal?)null));
        Assert.Equal("", TzNumericText.Format((double?)null));
        Assert.Equal("", TzNumericText.Format((int?)null));
        Assert.Equal("", TzNumericText.Format((long?)null));
        Assert.Equal("1,250", TzNumericText.Format((decimal?)1250m, Inv));
    }

    [Fact]
    public void Format_Double_And_Integer_Overloads()
    {
        // عدد اعشاری‌ای که N0 آن را گرد می‌کرد — نمایش باید اعشار را حفظ کند
        Assert.Equal("1,250.75", TzNumericText.Format(1250.75, Inv));
        Assert.Equal("0.5", TzNumericText.Format(0.5, Inv));
        Assert.Equal("1,234,567", TzNumericText.Format(1234567, Inv));
        Assert.Equal("9,223,372,036,854,775,807", TzNumericText.Format(long.MaxValue, Inv));
        Assert.Equal("12.5", TzNumericText.Format(12.5000m, Inv)); // صفرهای انتهایی حذف
    }

    // ── RejectionReason (پیام خطای ورودیِ ردشده) ──────────────────────

    private static string? Reason(string input, bool allowDecimal = true, CultureInfo? culture = null)
        => TzNumericText.RejectionReason(input, culture ?? Inv, allowDecimal);

    [Theory]
    [InlineData("")]
    [InlineData("-")]
    [InlineData(".")]
    public void RejectionReason_Null_For_MidTyping(string input)
    {
        Assert.Null(Reason(input)); // حالت‌های میانیِ تایپ نباید خطا بگیرند
    }

    [Fact]
    public void RejectionReason_Reports_Double_Decimal()
    {
        Assert.Equal("ممیز تکراری — فقط یک ممیز مجاز است.", Reason("12..5"));
        Assert.Equal("ممیز تکراری — فقط یک ممیز مجاز است.", Reason("1.2.3"));
    }

    [Fact]
    public void RejectionReason_Integer_Field_Rejects_Decimal()
    {
        Assert.Equal("در این فیلد فقط عدد صحیح مجاز است.", Reason("12.5", allowDecimal: false));
        Assert.Equal("در این فیلد فقط عدد صحیح مجاز است.",
                     Reason("۱۲٫۵", allowDecimal: false, culture: Fa)); // ممیز فارسی
    }

    [Fact]
    public void RejectionReason_Reports_Invalid_Characters()
    {
        var msg = "فقط ارقام، ممیز و جداکنندهٔ گروه مجاز است.";
        Assert.Equal(msg, Reason("12ab"));
        Assert.Equal(msg, Reason("--5"));
        Assert.Equal(msg, Reason("12+5"));
    }

    [Fact]
    public void RejectionReason_Reports_Overflow_As_Too_Large()
    {
        Assert.Equal("عدد واردشده بیش از حد بزرگ است.", Reason("999999999999999999999999999999"));
        Assert.Equal("عدد واردشده بیش از حد بزرگ است.", Reason("99999999999999999999", allowDecimal: false));
    }
}
