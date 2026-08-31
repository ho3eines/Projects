using Tarazin.Models;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گارد رفتاری <c>TreasurySourceLabels.For</c> — برچسب مفهومی «منبع چک» که در صفحهٔ
/// چک‌ها، گزارش سررسید، دیالوگ چاپ و PDF به‌صورت یکسان استفاده می‌شود.
/// برای هر پیشوندِ پشتیبانی‌شده سه حالت را قفل می‌کند:
///   ۱) نمونهٔ واقعی با شناسه (مثل GoldInvoice:24) → برچسب مفهومی فارسی؛
///   ۲) همان پیشوند با حروف کوچک‌/باCase مختلف (بدون حساسیت بزرگی/کوچکی حروف)؛
///   ۳) مقادیر بی‌مقدار (null / رشتهٔ خالی) و پیشوند ناشناخته → برچسب ایمن.
/// این‌ها تست واحد خالص‌اند و نیازمند دیتابیس نیستند (هیچ‌وقت Skip نمی‌شوند).
/// </summary>
public class TreasurySourceLabelsTests
{
    [Theory]
    [InlineData(null, "دستی")]
    [InlineData("", "دستی")]
    [InlineData("   ", "دستی")]
    [InlineData("-", "-")]
    [InlineData("foo", "foo")]
    [InlineData("NOT_A_PREFIX:123", "NOT_A_PREFIX:123")]
    public void For_null_empty_and_unknown_is_safe(string? source, string expected)
    {
        Assert.Equal(expected, TreasurySourceLabels.For(source));
    }

    [Theory]
    [InlineData("GoldInvoice:24", "فاکتور طلافروشی")]
    [InlineData("GoldInvoice:101", "فاکتور طلافروشی")]
    [InlineData("GoldPurchase:11", "فاکتور خرید طلا")]
    [InlineData("StoreOrder:4", "سفارش فروشگاه")]
    [InlineData("Order:7", "سفارش فروشگاه")]
    [InlineData("Invoice:9", "فاکتور فروشگاه")]
    [InlineData("Cheque:3", "وصول چک")]
    [InlineData("Payroll:2", "حقوق و دستمزد")]
    public void For_real_samples_maps_to_persian_labels(string source, string expected)
    {
        Assert.Equal(expected, TreasurySourceLabels.For(source));
    }

    [Theory]
    [InlineData("goldinvoice:24", "فاکتور طلافروشی")]
    [InlineData("GOLDINVOICE:24", "فاکتور طلافروشی")]
    [InlineData("goldpurchase:11", "فاکتور خرید طلا")]
    [InlineData("storeorder:4", "سفارش فروشگاه")]
    [InlineData("storeOrder:4", "سفارش فروشگاه")]
    [InlineData("order:7", "سفارش فروشگاه")]
    [InlineData("invoice:9", "فاکتور فروشگاه")]
    [InlineData("cheque:3", "وصول چک")]
    [InlineData("payroll:2", "حقوق و دستمزد")]
    [InlineData("PayROLL:1", "حقوق و دستمزد")]
    public void For_is_case_insensitive(string source, string expected)
    {
        Assert.Equal(expected, TreasurySourceLabels.For(source));
    }

    /// <summary>مقادیر با شناسهٔ واقعی باید منبع را با شناسهٔ خودش (و نه حذف) نگه دارند که UI بتواند عمیق شود.</summary>
    [Theory]
    [InlineData("GoldInvoice:24")]
    [InlineData("GoldPurchase:11")]
    [InlineData("StoreOrder:4")]
    [InlineData("Order:7")]
    [InlineData("Cheque:3")]
    [InlineData("Payroll:2")]
    public void For_keeps_source_id_for_deep_link(string source)
    {
        // برچسب مفهومی است؛ خودِ SourceReference خام (با شناسه) در جای دیگر حفظ می‌شود.
        var label = TreasurySourceLabels.For(source);
        Assert.False(string.IsNullOrEmpty(label));
        Assert.DoesNotContain(":", label.Replace("فاکتور", "").Replace("سفارش", "").Replace("حقوق", ""));
        Assert.NotEqual("دستی", label);
    }
}