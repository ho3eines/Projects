namespace Tarazin.Data.Services;

/// <summary>
/// محاسبهٔ مالیات بر درآمد حقوق (Income Tax) به‌صورت پلکانی.
///
/// منطق:
///  - هر نفر تحت تکفل، مقدار ثابتی از درآمد مشمول مالیات کم می‌کند (معافیتِ
///    تحت‌تکفل). استناد: معافیت‌های مادهٔ ۸۴/۸۷ قانون مالیات‌های مستقیم.
///  - پس از کسر کمک‌تکفل، درآمد مشمول با جدول نرخ‌های پلکانی محاسبه می‌شود؛
///    هر مبلغِ داخل هر پله فقط با نرخ همان پله مشمول می‌شود.
///  - اگر تعداد تحت‌تکفل آن‌قدر زیاد باشد که درآمد مشمول صفر یا منفی شود،
///    مالیات صفر برمی‌گردد؛ هزینه (مالیات منفی) پرداخت نمی‌شود.
///
/// جدول نرخ‌ها و معافیت‌های تک نفره برای ساده‌سازی در کد ثابت نگه‌داشته شده
/// تا سرویس بدون وابستگی به دیتابیس قابل تست و استفاده باشد.
/// </summary>
public sealed class PayrollTaxService
{
    /// <summary>معافیت هر نفر تحت تکفل از درآمد مشمول مالیات.</summary>
    public const decimal ExemptionPerDependent = 1_000_000m;

    /// <summary>پله‌های مالیاتی (سقف پله + نرخ). مرتب‌سازی صعودی بر اساس سقف.</summary>
    public static readonly IReadOnlyList<TaxBracket> Brackets = new[]
    {
        new TaxBracket(10_000_000m, 0.10m),          // تا ۱۰ میلیون → ۱۰٪
        new TaxBracket(30_000_000m, 0.20m), // از ۱۰ تا ۳۰ میلیون → ۲۰٪
        new TaxBracket(decimal.MaxValue, 0.30m) // بیش از ۳۰ میلیون → ۳۰٪
    };

    /// <summary>
    /// مالیات بر درآمد حقوق را با در نظر گرفتن تعداد افراد تحت تکفل محاسبه می‌کند.
    /// </summary>
    /// <param name="gross">درآمد ناخالص سالانه.</param>
    /// <param name="dependents">تعداد افراد تحت تکفل (۰ یا بیشتر).</param>
    /// <returns>مبلغ مالیات (هرگز منفی نیست).</returns>
    public decimal CalculateIncomeTax(decimal gross, int dependents)
    {
        if (gross < 0m)
            throw new ArgumentOutOfRangeException(nameof(gross), "درآمد ناخالص نمی‌تواند منفی باشد.");
        if (dependents < 0)
            throw new ArgumentOutOfRangeException(nameof(dependents), "تعداد تحت تکفل نمی‌تواند منفی باشد.");

        var taxable = gross - dependents * ExemptionPerDependent;
        if (taxable <= 0m)
            return 0m;

        var tax = 0m;
        var lower = 0m;
        foreach (var bracket in Brackets)
        {
            var upper = bracket.Ceiling;
            if (taxable <= lower)
                break;

            var band = Math.Min(taxable, upper) - lower;
            tax += decimal.Round(band * bracket.Rate, 2, MidpointRounding.AwayFromZero);
            lower = upper;
        }

        return tax;
    }

    /// <summary>یک پلهٔ مالیاتی: سقف درآمدِ مشمول با <see cref="Rate"/> نرخ.</summary>
    public readonly record struct TaxBracket(decimal Ceiling, decimal Rate);
}