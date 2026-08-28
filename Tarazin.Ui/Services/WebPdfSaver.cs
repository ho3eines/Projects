using Microsoft.JSInterop;

namespace Tarazin.Services;

/// <summary>ذخیرهٔ PDF در هاست وب — دانلود بلاب از طریق JS بدون دیالوگ پرینتر.</summary>
public sealed class WebPdfSaver : IPdfSaver
{
    private readonly IJSRuntime _js;

    public WebPdfSaver(IJSRuntime js) => _js = js;

    public async Task SaveAsync(string fileName, byte[] pdfBytes, CancellationToken ct = default)
    {
        var base64 = Convert.ToBase64String(pdfBytes);
        var ok = await _js.InvokeAsync<bool>("tarazin.downloadPdfBytes", ct, fileName, base64);
        if (!ok)
            throw new InvalidOperationException("دانلود PDF در مرورگر پشتیبانی نمی‌شود.");
    }
}
