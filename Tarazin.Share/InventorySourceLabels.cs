namespace Tarazin.Models;

/// <summary>
/// تبدیل پیشوند <c>SourceReference</c> حرکات انبار به برچسب مفهومی فارسی.
/// منبع واحد برای «اسناد روز انبار» (InventoryHome) و «کاردکس کالا» (InventoryReports)
/// تا فیلتر و نمایش مبدأ همه‌جا یکسان باشد.
/// پیشوندها: StoreOrder (فروشگاه)، PINV (فاکتور خرید)، SINV (فاکتور فروش)،
/// RET (برگشت)، Transfer (انتقال)، Stocktake (انبارگردانی)، Manual (دستی).
/// </summary>
public static class InventorySourceLabels
{
    /// <summary>گزینه‌های فیلتر «مبدأ حرکت» — (پیشوند، برچسب فارسی).</summary>
    public static readonly (string Key, string Label)[] Options = new[]
    {
        ("StoreOrder", "فروشگاه"),
        ("PINV", "فاکتور خرید"),
        ("SINV", "فاکتور فروش"),
        ("RET", "برگشت"),
        ("Transfer", "انتقال"),
        ("Stocktake", "انبارگردانی"),
        ("Manual", "دستی")
    };

    /// <summary>برچسب مفهومی برای پیشوند/مقدار خام SourceType؛ رشتهٔ خالی/null ← «—».</summary>
    public static string For(string? type)
    {
        if (string.IsNullOrWhiteSpace(type))
            return "—";
        foreach (var o in Options)
            if (string.Equals(o.Key, type, StringComparison.OrdinalIgnoreCase))
                return o.Label;
        return type;
    }
}