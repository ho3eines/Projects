namespace Tarazin.Services;

/// <summary>
/// ذخیره‌سازی فایل PDF ساخته‌شده توسط <see cref="PdfReportService"/> در هاست.
///
/// - هاست وب (Blazor Server): بلاب ساخته می‌شود و با یک anchor مخفی در مرورگر
///   دانلود می‌شود (بدون رفتن به دیالوگ پرینتر).
/// - هاست MAUI: فایل در ذخیره‌گاه اپ (FileSystem.AppDataDirectory) نوشته و با
///   Launcher باز می‌شود — بدون html2pdf و بدون رندر WebView.
/// </summary>
public interface IPdfSaver
{
    /// <summary>ذخیره/دانلود بایت‌های PDF با نام داده‌شده. خطا را پرتاب می‌کند تا UI آن را نشان دهد.</summary>
    Task SaveAsync(string fileName, byte[] pdfBytes, CancellationToken ct = default);
}
