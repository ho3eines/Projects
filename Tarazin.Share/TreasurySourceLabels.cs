namespace Tarazin.Models;

/// <summary>
/// تبدیل <c>SourceReference</c> چک‌ها/حرکات به برچسب مفهومی فارسی.
/// منبع واحد برای صفحهٔ چک‌ها، گزارش سررسید، دیالوگ چاپ و PDF تا همه‌جا یکسان نمایش
/// داده شود (مثل <c>GoldInvoice:24</c> ← «فاکتور طلافروشی» و <c>StoreOrder:4</c> ← «سفارش فروشگاه»).
/// </summary>
public static class TreasurySourceLabels
{
    /// <summary>برچسب مفهومی برای یک SourceReference (چک/سند/سفارش).</summary>
    public static string For(string? source)
    {
        // null / رشتهٔ خالی / فقط-فاصله همگی یعنی «منبعی ثبت نشده» → دستی.
        if (string.IsNullOrWhiteSpace(source))
            return "دستی";

        return source switch
        {
        var s when s.StartsWith("GoldInvoice:", StringComparison.OrdinalIgnoreCase) => "فاکتور طلافروشی",
        var s when s.StartsWith("GoldPurchase:", StringComparison.OrdinalIgnoreCase) => "فاکتور خرید طلا",
        var s when s.StartsWith("StoreOrder:", StringComparison.OrdinalIgnoreCase) => "سفارش فروشگاه",
        var s when s.StartsWith("Order:", StringComparison.OrdinalIgnoreCase) => "سفارش فروشگاه",
        var s when s.StartsWith("Invoice:", StringComparison.OrdinalIgnoreCase) => "فاکتور فروشگاه",
        var s when s.StartsWith("Cheque:", StringComparison.OrdinalIgnoreCase) => "وصول چک",
        var s when s.StartsWith("Payroll:", StringComparison.OrdinalIgnoreCase) => "حقوق و دستمزد",
        _ => source
        };
    }
}