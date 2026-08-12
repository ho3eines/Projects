using Microsoft.Extensions.Configuration;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using MudBlazor.Services;
using Tarazin.Services;

namespace Tarazin.Maui;

/// <summary>
/// MAUI Blazor Hybrid host — the shared UI (Tarazin.Ui) runs inside a
/// BlazorWebView with full access to the local .NET runtime. No web server
/// is involved: components render in-process and talk to SQL Server directly
/// through the shared DbService (Windows desktop target; see skill notes).
/// </summary>
public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();

        // Load the embedded appsettings.json so the shared layer can read
        // ConnectionStrings:DefaultConnection and Tarazin:* settings.
        //
        // اگر این منبع پیدا نشود، برنامه بی‌سروصدا بدون رشتهٔ اتصال بالا می‌آمد
        // و بعداً خطای گنگ می‌داد؛ حالا همان‌جا با پیام روشن شکست می‌خورد.
        using (var stream = typeof(MauiProgram).Assembly.GetManifestResourceStream("Tarazin.Maui.appsettings.json"))
        {
            if (stream is null)
                throw new InvalidOperationException(
                    "منبع «Tarazin.Maui.appsettings.json» در اسمبلی پیدا نشد. " +
                    "در Tarazin.Maui.csproj باید EmbeddedResource با همین LogicalName تعریف شده باشد.");

            builder.Configuration.AddJsonStream(stream);
        }

        // متغیرهای محیطی (از جمله TARAZIN_SQL_CONNECTION) بر مقدار فایل اولویت دارند.
        builder.Configuration.AddEnvironmentVariables();

        builder.UseMauiApp<App>();

        builder.Services.AddMauiBlazorWebView();
#if DEBUG
        builder.Services.AddBlazorWebViewDeveloperTools();
#endif

        // MudBlazor UI kit (same as the web host)
        builder.Services.AddMudServices();

        // Shared Tarazin services (DbService, ScriptCatalog, Auth, Audit, ...)
        builder.Services.AddTarazinUiServices();

        return builder.Build();
    }
}
