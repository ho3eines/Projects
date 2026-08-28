using Tarazin.Services;

namespace Tarazin.Maui;

/// <summary>
/// ذخیرهٔ PDF در هاست MAUI — فایل در ذخیره‌گاه اپ نوشته و با برنامهٔ PDF خوان
/// باز می‌شود. این مسیر بومی (SkiaSharp/QuestPDF) جایگزین html2pdf در WebView
/// است که روی موبایل سنگین بود.
/// </summary>
public sealed class MauiPdfSaver : IPdfSaver
{
    public async Task SaveAsync(string fileName, byte[] pdfBytes, CancellationToken ct = default)
    {
        if (pdfBytes.Length == 0)
            throw new InvalidOperationException("محتوای PDF خالی است.");

        var safeName = string.Concat(fileName.Where(ch =>
            !Path.GetInvalidFileNameChars().Contains(ch) && ch != '/' && ch != '\\'));

        var path = Path.Combine(FileSystem.AppDataDirectory, safeName);
        await File.WriteAllBytesAsync(path, pdfBytes, ct);

        // در اندروید بازکردن مستقیم فایل نیاز به FileProvider دارد؛ Launcher آن را مدیریت می‌کند.
        // PresentationSourceBounds فقط روی ویندوز (WinUI) لازم است و مقدار صفر برای پنهان‌کردن پنجرهٔ بازکننده کافی است.
        var request = new OpenFileRequest { File = new ReadOnlyFile(path) };
        if (DeviceInfo.Platform == DevicePlatform.WinUI)
            request.PresentationSourceBounds = new Microsoft.Maui.Graphics.Rect(0, 0, 0, 0);

        await Launcher.Default.OpenAsync(request);
    }
}
