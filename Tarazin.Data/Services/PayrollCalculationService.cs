using Tarazin.Models;

namespace Tarazin.Data.Services;

/// <summary>
/// محاسبهٔ فیش حقوق یک کارمند در یک دوره از روی اقلام حقوق (مزایا/کسورات).
///
/// ترتیب محاسبه (مطابق منطق Finalize سمت SQL ولی قابل تست در C#):
///   تسهیم‌ها  = جمع اقلام غیرکسوری (مزایا)
///   کسورات    = جمع اقلام کسوری (بیمه، مالیاتِ ثابت، وام ...)
///   ناخالص    = تسهیم‌ها  (اقلام کسوری در محاسبهٔ ناخالص ندارند)
///   مالیات    = PayrollTaxService.CalculateIncomeTax(ناخالص، تعداد تحت تکفل)
///   خالص      = ناخالص − کسورات − مالیات
///
/// این کلاس سرویس محاسبهٔ خالص پرداختی را از منطق اسکریپت SQL جدا نگه
/// می‌دارد تا بتوان با تست‌های Unit به‌طور مستقل از دیتابیس صحت آن را
/// تضمین کرد. UI و آیندهٔ Finalize می‌توانند از همین سرویس استفاده کنند.
/// </summary>
public sealed class PayrollCalculationService
{
    private readonly PayrollTaxService _taxService;

    public PayrollCalculationService(PayrollTaxService taxService)
    {
        _taxService = taxService;
    }

    /// <summary>
    /// محاسبهٔ خالص پرداختی از لیست اقلام حقوق یک کارمند.
    /// </summary>
    /// <param name="items">اقلام حقوق دورهٔ جاری (مزایا و کسورات).</param>
    /// <param name="dependents">تعداد افراد تحت تکفل کارمند (برای مالیات).</param>
    public PayrollCalculationResult Compute(IEnumerable<SalaryItemRow> items, int dependents = 0)
    {
        ArgumentNullException.ThrowIfNull(items);

        decimal earnings = 0m;
        decimal deductions = 0m;
        foreach (var item in items)
        {
            // مقدار به علامت مثبت نرمال می‌شود (سبک SQL که با IsDeduction
            // علامت را تعیین می‌کند) تا input تغییری نکند.
            var amount = item.Amount < 0m ? -item.Amount : item.Amount;

            if (item.IsDeduction)
                deductions += amount;
            else
                earnings += amount;
        }

        var tax = _taxService.CalculateIncomeTax(earnings, dependents);
        var net = earnings - deductions - tax;

        return new PayrollCalculationResult(
            Earnings: earnings,
            Deductions: deductions,
            GrossIncome: earnings,
            IncomeTax: tax,
            NetPay: net);
    }

    /// <summary>
    /// محاسبهٔ خالص از مبالغِ ازپیش‌تجمیع‌شده (تسهیم‌ها و کسورات کل یک دوره).
    /// برای گزارش فیش حقوق که aggregations را از اسکریپت می‌گیرد، از همین سرویس
    /// استفاده می‌کند تا منطق مالیات/خالص یکسان بماند.
    /// </summary>
    public PayrollCalculationResult ComputeFromTotals(decimal earnings, decimal deductions, int dependents = 0)
    {
        if (earnings < 0m)
            throw new ArgumentOutOfRangeException(nameof(earnings));
        if (deductions < 0m)
            throw new ArgumentOutOfRangeException(nameof(deductions));

        var tax = _taxService.CalculateIncomeTax(earnings, dependents);
        var net = earnings - deductions - tax;

        return new PayrollCalculationResult(
            Earnings: earnings,
            Deductions: deductions,
            GrossIncome: earnings,
            IncomeTax: tax,
            NetPay: net);
    }
}

/// <summary>گزارش محاسبهٔ فیش حقوق: تسهیم‌ها، کسورات، مالیات و خالص.</summary>
public readonly record struct PayrollCalculationResult(
    decimal Earnings,
    decimal Deductions,
    decimal GrossIncome,
    decimal IncomeTax,
    decimal NetPay);