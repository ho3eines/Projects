using Microsoft.Extensions.Logging;

namespace Tarazin.Maui;

/// <summary>
/// آخرین‌خط تشخیص برای Release ویندوز.
///
/// چرا لازم است: در بیلد Release هیچ Output window ای وجود ندارد و
/// <c>BlazorWebView</c> خطاهای سرو کردن فایل را فقط از طریق <see cref="ILogger"/>
/// گزارش می‌کند (رده‌های <c>Microsoft.AspNetCore.Components.WebView</c>). اگر آن
/// لاگ‌ها جایی نوشته نشوند، تنها چیزی که کاربر می‌بیند صفحهٔ خطای خود Edge است
/// (<c>ERR_CONNECTION_CLOSED</c> روی <c>0.0.0.0</c>) که هیچ اطلاعاتی نمی‌دهد.
///
/// این provider همان لاگ‌ها را در همان فایلی می‌نویسد که StartupCrashLog می‌نویسد:
/// <c>%LocalAppData%\Tarazin\maui-crash.log</c>
/// </summary>
internal sealed class StartupFileLoggerProvider : ILoggerProvider
{
    public ILogger CreateLogger(string categoryName) => new StartupFileLogger(categoryName);

    public void Dispose()
    {
        // چیزی برای آزادسازی نیست؛ نوشتن روی فایل، append ساده است.
    }

    private sealed class StartupFileLogger : ILogger
    {
        private readonly string _category;

        internal StartupFileLogger(string category)
        {
            // نام کامل رده طولانی است؛ فقط بخش آخر برای خوانایی لاگ نگه داشته می‌شود.
            var lastDot = category.LastIndexOf('.');
            _category = lastDot >= 0 && lastDot < category.Length - 1
                ? category[(lastDot + 1)..]
                : category;
        }

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => logLevel != LogLevel.None;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel))
                return;

            try
            {
                var message = formatter(state, exception);
                if (string.IsNullOrWhiteSpace(message) && exception is null)
                    return;

                StartupCrashLog.Write($"[{logLevel}] {_category}: {message}", exception);
            }
            catch
            {
                // یک logger هرگز نباید برنامه را بشکند.
            }
        }
    }
}
