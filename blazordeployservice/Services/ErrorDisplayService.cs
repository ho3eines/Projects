using System;
using System.Net.Http;
using System.Threading.Tasks;

namespace BlazorDeployService.Services;

/// <summary>
/// سرویس نمایش خطا — همه‌ی خطاهای برنامه (شبکه، احراز هویت، درخواست و …)
/// را به پیام فارسی خوانا تبدیل کرده و از طریق IAlertService به کاربر نمایش می‌دهد.
///
/// نحوه استفاده در صفحات:
///   @inject IErrorDisplayService Errors
///   try { ... } catch (Exception ex) { await Errors.ShowAsync(ex); }
/// </summary>
public interface IErrorDisplayService
{
    /// <summary>نمایش خطا با عنوان و پیام دلخواه</summary>
    Task ShowErrorAsync(string message, string? title = null, int duration = 6000);

    /// <summary>نمایش هشدار</summary>
    Task ShowWarningAsync(string message, string? title = null, int duration = 6000);

    /// <summary>نمایش پیام موفقیت</summary>
    Task ShowSuccessAsync(string message, string? title = null, int duration = 5000);

    /// <summary>نمایش اطلاع‌رسانی</summary>
    Task ShowInfoAsync(string message, string? title = null, int duration = 5000);

    /// <summary>
    /// نمایش خودکار هر نوع استثنا — نوع خطا تشخیص داده می‌شود
    /// (اتصال به سرور، مهلت درخواست، نشست منقضی، خطای سرور و …)
    /// </summary>
    Task ShowAsync(Exception exception, string? context = null, int duration = 7000);
}

public sealed class ErrorDisplayService : IErrorDisplayService
{
    private readonly IAlertService _alert;

    public ErrorDisplayService(IAlertService alert)
    {
        _alert = alert;
    }

    public Task ShowErrorAsync(string message, string? title = null, int duration = 6000)
        => _alert.ShowErrorAsync(title ?? "خطا", message, duration);

    public Task ShowWarningAsync(string message, string? title = null, int duration = 6000)
        => _alert.ShowWarningAsync(title ?? "هشدار", message, duration);

    public Task ShowSuccessAsync(string message, string? title = null, int duration = 5000)
        => _alert.ShowSuccessAsync(title ?? "موفق", message, duration);

    public Task ShowInfoAsync(string message, string? title = null, int duration = 5000)
        => _alert.ShowInfoAsync(title ?? "اطلاع", message, duration);

    public Task ShowAsync(Exception exception, string? context = null, int duration = 7000)
    {
        var (title, message) = Describe(exception);
        if (!string.IsNullOrWhiteSpace(context))
            title = $"{title} — {context}";
        return _alert.ShowErrorAsync(title, message, duration);
    }

    /// <summary>تبدیل استثنا به (عنوان، پیام) خوانای فارسی</summary>
    private static (string Title, string Message) Describe(Exception ex)
    {
        switch (ex)
        {
            case RequestServiceException rse when rse.Code == "SESSION_EXPIRED":
                return ("نشست منقضی شده",
                    "نشست شما به پایان رسیده است. لطفاً دوباره وارد شوید.");

            case RequestServiceException rse when rse.Code == "EMPTY_RESPONSE":
                return ("پاسخ نامعتبر", rse.Message);

            case RequestServiceException rse:
                return ("خطای درخواست", rse.Message);

            case AuthException ae when ae.StatusCode == 401:
                return ("احراز هویت ناموفق",
                    "نام کاربری، رمز عبور یا توکن ورود اشتباه است. دوباره تلاش کنید.");

            case AuthException ae:
                return ("خطای ورود", ae.Message);

            case HttpRequestException:
                return ("اتصال به سرور برقرار نشد",
                    "امکان ارتباط با سرور وجود ندارد. اتصال اینترنت و روشن بودن سرویس سرور را بررسی کنید.");

            case OperationCanceledException:
            case TimeoutException:
                return ("مهلت درخواست تمام شد",
                    "سرور در زمان مقرر پاسخ نداد. لطفاً کمی بعد دوباره تلاش کنید.");

            default:
                return ("خطای غیرمنتظره", ex.Message);
        }
    }
}
