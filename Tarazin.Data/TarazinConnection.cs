using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Tarazin.Data;

/// <summary>
/// تنها نقطهٔ خواندن و اعتبارسنجی رشتهٔ اتصال (ConnectionString) در کل برنامه.
///
/// چرا این کلاس لازم شد؟ پیش از این هر سرویس (DbService/AuditService) خودش
/// <c>config.GetConnectionString("DefaultConnection")</c> را می‌خواند و اگر
/// چیزی اشتباه بود فقط یک پیام خشک می‌داد؛ تشخیص «اصلاً کانکشن‌استرینگ خوانده
/// شد یا نه؟» ممکن نبود. حالا:
///
///   1. ترتیب منابع مشخص است (env → configuration)،
///   2. رشته با <see cref="SqlConnectionStringBuilder"/> اعتبارسنجی می‌شود،
///   3. خطاها فارسی و راهنما دارند،
///   4. نسخهٔ ماسک‌شده برای نمایش در صفحهٔ عیب‌یابی (/diag) تولید می‌شود.
/// </summary>
public static class TarazinConnection
{
    /// <summary>نام کلید در <c>ConnectionStrings</c>.</summary>
    public const string Name = "DefaultConnection";

    /// <summary>
    /// متغیر محیطی مستقل از هاست (وب و MAUI). اگر مقدار داشته باشد بر
    /// appsettings.json اولویت دارد — برای تولید/Docker/secret store.
    /// (در هاست وب، <c>ConnectionStrings__DefaultConnection</c> هم خودکار کار می‌کند.)
    /// </summary>
    public const string EnvVariable = "TARAZIN_SQL_CONNECTION";

    /// <summary>
    /// رشتهٔ اتصال معتبر را برمی‌گرداند، وگرنه استثنا با پیام راهنما پرتاب می‌کند.
    /// </summary>
    public static string Resolve(IConfiguration? config)
    {
        var (value, source) = ResolveRaw(config);

        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException(
                $"رشتهٔ اتصال پیدا نشد: نه متغیر محیطی «{EnvVariable}» مقدار دارد و نه " +
                $"کلید «ConnectionStrings:{Name}» در appsettings.json خوانده شده است. " +
                "اگر هاست وب است، appsettings.json باید کنار خروجی برنامه کپی شود؛ " +
                "اگر MAUI است، appsettings.json باید به‌صورت EmbeddedResource با نام " +
                "«Tarazin.Maui.appsettings.json» در اسمبلی باشد.");

        try
        {
            var builder = new SqlConnectionStringBuilder(value);

            if (string.IsNullOrWhiteSpace(builder.DataSource))
                throw new InvalidOperationException(
                    $"رشتهٔ اتصال (منبع: {source}) مقدار Server/Data Source ندارد.");

            if (string.IsNullOrWhiteSpace(builder.InitialCatalog))
                throw new InvalidOperationException(
                    $"رشتهٔ اتصال (منبع: {source}) مقدار Database/Initial Catalog ندارد.");

            // مهلت اتصالِ بی‌نهایت (0) یا خیلی طولانی باعث می‌شود صفحهٔ عیب‌یابی
            // به‌جای گزارش خطا فقط هنگ کند؛ سقف ۶۰ ثانیه کافی است.
            if (builder.ConnectTimeout <= 0 || builder.ConnectTimeout > 60)
                builder.ConnectTimeout = 30;

            // اگر خودِ رشته Application Name نداده، «Tarazin» بگذار تا در
            // sys.dm_exec_sessions قابل تشخیص باشد (کلید موجود را بازنویسی نکن).
            //
            // نکته: ContainsKey در SqlConnectionStringBuilder برای هر کلیدِ
            // معتبر true برمی‌گرداند (چه ست شده باشد چه نه)؛ ShouldSerialize
            // است که فقط برای کلیدهای صریحاً ست‌شده true می‌دهد.
            if (!builder.ShouldSerialize("Application Name"))
                builder.ApplicationName = "Tarazin";

            return builder.ConnectionString;
        }
        catch (ArgumentException ex)
        {
            // مثلاً کلید ناشناخته یا رمزی که «;» دارد و داخل {} گذاشته نشده است.
            throw new InvalidOperationException(
                $"رشتهٔ اتصال (منبع: {source}) قابل تجزیه نیست: {ex.Message}. " +
                "اگر رمز عبور شامل «;» یا «=» است، آن را داخل {} بگذارید؛ مثال: Password={pa;ss}.",
                ex);
        }
    }

    /// <summary>
    /// خواندن خام بدون اعتبارسنجی: مقدار + نام منبع. برای صفحهٔ عیب‌یابی.
    /// </summary>
    public static (string? Value, string Source) ResolveRaw(IConfiguration? config)
    {
        var fromEnv = Environment.GetEnvironmentVariable(EnvVariable);
        if (!string.IsNullOrWhiteSpace(fromEnv))
            return (fromEnv, $"متغیر محیطی {EnvVariable}");

        var fromConfig = config?.GetConnectionString(Name);
        if (!string.IsNullOrWhiteSpace(fromConfig))
            return (fromConfig, $"پیکربندی ConnectionStrings:{Name}");

        return (null, "پیدا نشد");
    }

    /// <summary>
    /// همان رشته ولی به دیتابیس <c>master</c> — برای ساخت دیتابیس در اولین اجرا.
    /// </summary>
    public static string ToMaster(string connectionString)
        => new SqlConnectionStringBuilder(connectionString)
        {
            InitialCatalog = "master"
        }.ConnectionString;

    /// <summary>نام دیتابیس مقصد.</summary>
    public static string DatabaseName(string connectionString)
        => new SqlConnectionStringBuilder(connectionString).InitialCatalog;

    /// <summary>
    /// نسخهٔ ایمن برای نمایش/لاگ: رمز عبور همیشه ماسک می‌شود.
    /// </summary>
    public static string Mask(string? connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
            return "(خالی)";

        try
        {
            var b = new SqlConnectionStringBuilder(connectionString);
            if (!string.IsNullOrEmpty(b.Password))
                b.Password = "********";
            return b.ConnectionString;
        }
        catch (ArgumentException)
        {
            // غیرقابل تجزیه: دست‌کم مقدار Password را با regex ساده پنهان کن.
            return System.Text.RegularExpressions.Regex.Replace(
                connectionString, @"(?i)(password|pwd)\s*=\s*[^;]*", "$1=********");
        }
    }
}
