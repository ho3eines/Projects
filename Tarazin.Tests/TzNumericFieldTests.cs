using System.Globalization;
using Bunit;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using MudBlazor;
using MudBlazor.Services;

// خواندنِ state پارامترهایِ MudTextField (Error/ErrorText/Value) برای سنجش در
// تست عمدی است؛ هشدار MUD0012 مربوط به کدِ UI واقعی است نه این فایل تست.
#pragma warning disable MUD0012
using Tarazin.Components;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// تست‌های کامپوننتی (bUnit) برای TzNumericField — گذارهای حالتِ خطا:
/// متنِ نامعتبر «می‌ماند» + پیام قرمز، پیش‌نویسِ خارج از بازه (Min/Max) در
/// blur/Enter به مقدارِ حد clamp می‌شود، سرریزِ انواعِ صحیح خطا می‌دهد نه
/// exception، و ریستِ مقدار از بیرون متن/خطا را همگام می‌کند.
///
/// محرکِ رویدادها مستقیماً EventCallbackهایِ MudTextField داخلی است
/// (ValueChanged/OnBlur/OnKeyUp) تا لایهٔ تبدیلِ متنِ MudBlazor دور زده شود و
/// تست روی منطقِ خودِ TzNumericField متمرکز باشد. نمایش با فرهنگ invariant
/// سنجیده می‌شود تا گروه‌بندی (مثل «1,234,567») قطعی باشد.
/// </summary>
public class TzNumericFieldTests : BunitContext
{
    /// <summary>گیرندهٔ مقادیر commitشده از کامپوننت (جای والدِ واقعی).</summary>
    private sealed class Sink<T>
    {
        public T? Value { get; private set; }
        public int CommitCount { get; private set; }

        public void Set(T v)
        {
            Value = v;
            CommitCount++;
        }
    }

    public TzNumericFieldTests()
    {
        // نمایشِ قطعی؛ منطقِ parser مستقل از فرهنگ است و کاربردِ واقعی fa-IR است
        CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;

        // MudBlazor 9.8: MudTextField به TimeProvider و سرویس‌های داخلی MudBlazor نیاز دارد
        Services.AddSingleton(TimeProvider.System);
        Services.AddMudServices();

        // MudInput در OnAfterRender یک فراخوانی JS بی‌اثر دارد — در تست نادیده بگیر
        JSInterop.Mode = JSRuntimeMode.Loose;
    }

    private IRenderedComponent<TzNumericField<T>> RenderField<T>(T value, Sink<T> sink,
                                                                 decimal? min = null, decimal? max = null)
    {
        return Render<TzNumericField<T>>(p =>
        {
            p.Add(x => x.Value, value);
            p.Add(x => x.ValueChanged, sink.Set);
            if (min.HasValue) p.Add(x => x.Min, (object)min.Value);
            if (max.HasValue) p.Add(x => x.Max, (object)max.Value);
        });
    }

    private static MudTextField<string> Field<T>(IRenderedComponent<TzNumericField<T>> cut)
        => cut.FindComponent<MudTextField<string>>().Instance;

    // رویدادها را داخل dispatcher رندر اجرا می‌کنیم (و فرهنگ را همان‌جا می‌چینیم،
    // چون خطای رندر ممکن است روی ترد دیگری اجرا شود).
    private Task TypeAsync<T>(IRenderedComponent<TzNumericField<T>> cut, MudTextField<string> field, string text)
        => cut.InvokeAsync(() =>
        {
            CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
            return field.ValueChanged.InvokeAsync(text);
        });

    private Task BlurAsync<T>(IRenderedComponent<TzNumericField<T>> cut, MudTextField<string> field)
        => cut.InvokeAsync(() =>
        {
            CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
            return field.OnBlur.InvokeAsync(new FocusEventArgs());
        });

    private Task EnterAsync<T>(IRenderedComponent<TzNumericField<T>> cut, MudTextField<string> field)
        => cut.InvokeAsync(() =>
        {
            CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
            return field.OnKeyUp.InvokeAsync(new KeyboardEventArgs { Key = "Enter" });
        });

    // ── ورودیِ نامعتبر: متن می‌ماند، خطای قرمز، commit نمی‌شود ────────────

    [Fact]
    public async Task DoubleDecimal_KeepsTypedText_ShowsError_AndDoesNotCommit()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink);
        var field = Field(cut);

        await TypeAsync(cut, field, "12..5");

        Assert.Equal("12..5", field.Value);            // متنِ تایپ‌شده دست‌نخورده
        Assert.True(field.Error);
        Assert.Equal("ممیز تکراری — فقط یک ممیز مجاز است.", field.ErrorText);
        Assert.Equal(0, sink.CommitCount);             // هیچ مقداری commit نشده
        Assert.Equal(0m, cut.Instance.Value);
    }

    [Fact]
    public async Task PersianDigits_Commit_Grouped_And_NoError()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink);
        var field = Field(cut);

        await TypeAsync(cut, field, "۱۲۳۴۵۶۷");

        Assert.False(field.Error);
        Assert.Equal(1, sink.CommitCount);
        Assert.Equal(1234567m, sink.Value);
        Assert.Equal("1,234,567", field.Value);        // نرمال‌سازی + گروه‌بندی زنده
    }

    // ── حالت‌های میانیِ تایپ خطا نمی‌گیرند ───────────────────────────────

    [Theory]
    [InlineData("-")]
    [InlineData(".")]
    public async Task MidTyping_States_ShowNoError(string text)
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink);
        var field = Field(cut);

        await TypeAsync(cut, field, text);

        Assert.False(field.Error);
        Assert.Equal(text, field.Value);
        Assert.Equal(0, sink.CommitCount);
    }

    [Fact]
    public async Task Clearing_Empty_Commits_Default_And_Clears_Error()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(5m, sink);
        var field = Field(cut);

        await TypeAsync(cut, field, "12..5"); // اول خطا
        Assert.True(field.Error);

        await TypeAsync(cut, field, "");
        Assert.False(field.Error);
        Assert.Equal("", field.Value);
        Assert.True(sink.Value is 0m); // decimal غیر-nullable → صفر
    }

    // ── خارج از بازهٔ Min/Max: پیش‌نویس قرمز، clamp در blur/Enter ─────────

    [Fact]
    public async Task BelowMin_WhileTyping_KeepsDraft_ShowsError_And_BlurClampsToMin()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink, min: 0m);
        var field = Field(cut);

        await TypeAsync(cut, field, "-5");

        Assert.Equal("-5", field.Value);               // وسط تایپ clamp نمی‌شود
        Assert.True(field.Error);
        Assert.Equal("حداقل مجاز: 0", field.ErrorText);
        Assert.Equal(0, sink.CommitCount);             // هنوز commit نشده

        await BlurAsync(cut, field);

        Assert.Equal("0", field.Value);                // blur → clamp به حد
        Assert.False(field.Error);
        Assert.Equal(1, sink.CommitCount);
        Assert.True(sink.Value is 0m);
    }

    [Fact]
    public async Task BelowMin_Enter_ClampsToMin_EvenWhileFocused()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink, min: 0m);
        var field = Field(cut);

        await TypeAsync(cut, field, "-7");
        Assert.True(field.Error);

        await EnterAsync(cut, field);

        Assert.Equal("0", field.Value);
        Assert.False(field.Error);
        Assert.True(sink.Value is 0m);
    }

    [Fact]
    public async Task AboveMax_WhileTyping_ShowsError_And_BlurClampsToMax()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink, max: 100m);
        var field = Field(cut);

        await TypeAsync(cut, field, "150");

        Assert.Equal("150", field.Value);
        Assert.True(field.Error);
        Assert.Equal("حداکثر مجاز: 100", field.ErrorText);
        Assert.Equal(0, sink.CommitCount);

        await BlurAsync(cut, field);

        Assert.Equal("100", field.Value);
        Assert.False(field.Error);
        Assert.True(sink.Value is 100m);
    }

    [Fact]
    public async Task InRange_Blur_DoesNotResend_Or_Error()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink, min: 0m);
        var field = Field(cut);

        await TypeAsync(cut, field, "8"); // معتبر → بلافاصله commit
        Assert.Equal(1, sink.CommitCount);
        Assert.False(field.Error);

        await BlurAsync(cut, field);     // بدون پیش‌نویسِ خارج از بازه → بی‌اثر

        Assert.Equal(1, sink.CommitCount);
        Assert.False(field.Error);
        Assert.Equal("8", field.Value);
    }

    // ── انواع صحیح ───────────────────────────────────────────────────────

    [Fact]
    public async Task IntegerField_DecimalTyping_ShowsIntegerOnlyError_AndDoesNotCommit()
    {
        var sink = new Sink<int>();
        var cut = RenderField(0, sink);
        var field = Field(cut);

        await TypeAsync(cut, field, "12.5");

        Assert.Equal("12.5", field.Value);
        Assert.True(field.Error);
        Assert.Equal("در این فیلد فقط عدد صحیح مجاز است.", field.ErrorText);
        Assert.Equal(0, sink.CommitCount);
    }

    [Fact]
    public async Task IntegerField_Overflow_ShowsRangeError_InsteadOfCrashing()
    {
        var sink = new Sink<int>();
        var cut = RenderField(0, sink);
        var field = Field(cut);

        // ۹۹۹۹۹۹۹۹۹۹۹۹۹۹ ≫ int.MaxValue (2147483647) — قبل از این رفع،
        // Convert.ChangeType داخل CommitAsync OverflowException می‌داد
        await TypeAsync(cut, field, "99999999999999");

        Assert.Equal("99999999999999", field.Value);
        Assert.True(field.Error);
        Assert.Equal("عدد از محدودهٔ مجاز این فیلد فراتر است.", field.ErrorText);
        Assert.Equal(0, sink.CommitCount);
        Assert.Equal(0, cut.Instance.Value);
    }

    [Fact]
    public async Task IntegerField_ValidInput_Commits()
    {
        var sink = new Sink<int>();
        var cut = RenderField(0, sink, min: 0m);
        var field = Field(cut);

        await TypeAsync(cut, field, "42");

        Assert.False(field.Error);
        Assert.Equal(1, sink.CommitCount);
        Assert.True(sink.Value is 42);
    }

    // ── تغییرِ مقدار از بیرون (والد/فرم) ─────────────────────────────────

    [Fact]
    public async Task ExternalValueReset_ClearsError_And_SyncsText()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink);
        var field = Field(cut);

        await TypeAsync(cut, field, "12..5");
        Assert.True(field.Error);

        cut.Render(p => p.Add(x => x.Value, 42m));

        var after = Field(cut);
        Assert.False(after.Error);
        Assert.Equal("42", after.Value);
        Assert.Equal(0, sink.CommitCount); // تغییرِ بیرونی commit به حساب نمی‌آید
    }

    [Fact]
    public async Task UnrelatedParentRender_DoesNotClobber_MidDraftText()
    {
        var sink = new Sink<decimal>();
        var cut = RenderField(0m, sink, min: 0m);
        var field = Field(cut);

        await TypeAsync(cut, field, "-5"); // پیش‌نویس خارج از بازه
        Assert.Equal("-5", field.Value);

        // والد با همان Value دوباره رندر می‌کند (گارد _lastEmitted) —
        // متنِ در حال تایپ نباید به آخرین مقدارِ commitشده برگردد
        cut.Render(p => p.Add(x => x.Value, 0m));

        var after = Field(cut);
        Assert.Equal("-5", after.Value);
        Assert.True(after.Error);
    }
}
