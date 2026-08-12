using System;

namespace BlazorDeployService.Helper;

/// <summary>
/// ساخت امن URL آدرس سرور — جلوگیری از اسلش‌های تکراری.
///
/// مشکل رایج: وقتی BaseUrl با "/" تمام شود و مسیر نسبی هم با "/" شروع شود
/// نتیجه‌ای مثل «https://localhost:65222//api/auth/login» ساخته می‌شود که
/// توسط سرور/پروکسی به‌درستی هدایت نمی‌شود. این کلاس همیشه دقیقاً یک
/// اسلش جداکننده بین BaseUrl و مسیر قرار می‌دهد.
/// </summary>
public static class ApiUrl
{
    /// <summary>
    /// دو بخش آدرس را با دقیقاً یک اسلش به هم می‌چسباند.
    /// مثال: Combine("https://localhost:65222/", "/api/auth/login")
    ///       → "https://localhost:65222/api/auth/login"
    /// </summary>
    public static string Combine(string? baseUrl, string? relativePath)
    {
        var path = NormalizeRelative(relativePath);
        if (path.Length == 0)
            return NormalizeBase(baseUrl);

        var baseNorm = NormalizeBase(baseUrl);
        if (baseNorm.Length == 0)
            return "/" + path;

        return baseNorm + "/" + path;
    }

    /// <summary>اسلش پایانی و فاصله‌های اضافی را از BaseUrl حذف می‌کند.</summary>
    public static string NormalizeBase(string? baseUrl)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
            return string.Empty;
        return baseUrl.Trim().TrimEnd('/');
    }

    private static string NormalizeRelative(string? relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath))
            return string.Empty;
        var rel = relativePath.Trim();
        return rel.StartsWith('/') ? rel[1..] : rel;
    }
}
