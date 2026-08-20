namespace Tarazin.Maui;

/// <summary>
/// Last-resort crash log for MAUI. WinUI/BlazorWebView often swallow startup
/// exceptions (no dialog, no console) — this file is the place to look.
/// Path: %LocalAppData%\Tarazin\maui-crash.log
/// </summary>
internal static class StartupCrashLog
{
    internal static string FilePath { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Tarazin", "maui-crash.log");

    internal static void Write(string title, Exception? ex = null)
    {
        try
        {
            var dir = Path.GetDirectoryName(FilePath);
            if (!string.IsNullOrEmpty(dir))
                Directory.CreateDirectory(dir);

            var body = ex is null ? title : $"{title}{Environment.NewLine}{ex}";
            File.AppendAllText(FilePath,
                $"==== {DateTime.Now:yyyy-MM-dd HH:mm:ss} ===={Environment.NewLine}{body}{Environment.NewLine}{Environment.NewLine}");
        }
        catch
        {
            // Never throw from a crash logger.
        }
    }
}
