using System.Globalization;
using Microsoft.AspNetCore.Components.WebView.Maui;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using MudBlazor;
using MudBlazor.Services;
using Tarazin.Data;
using Tarazin.Services;

namespace Tarazin.Maui;

/// <summary>
/// MAUI Blazor Hybrid host — the shared UI (Tarazin.Ui) runs inside a
/// BlazorWebView with full access to the local .NET runtime. Authentication
/// and short-lived SQL connection preparation go through the HTTPS broker;
/// existing business operations continue through the shared DbService.
/// </summary>
public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();

        // The embedded MAUI configuration contains only the public HTTPS API
        // endpoint. SQL credentials and tokens are never packaged here.
        using (var stream = typeof(MauiProgram).Assembly.GetManifestResourceStream("Tarazin.Maui.appsettings.json"))
        {
            if (stream is null)
                throw new InvalidOperationException(
                    "منبع «Tarazin.Maui.appsettings.json» در اسمبلی پیدا نشد. " +
                    "در Tarazin.Maui.csproj باید EmbeddedResource با همین LogicalName تعریف شده باشد.");

            builder.Configuration.AddJsonStream(stream);
        }

        // A deployment may override only this non-secret endpoint.
        var endpointOverride = Environment.GetEnvironmentVariable("TARAZIN_SERVER_ENDPOINT");
        if (!string.IsNullOrWhiteSpace(endpointOverride))
            builder.Configuration["ServerEndpoint"] = endpointOverride.Trim();

        builder.UseMauiApp<App>();

        builder.Services.AddMauiBlazorWebView();
#if DEBUG
        builder.Services.AddBlazorWebViewDeveloperTools();
#endif

        var fa = CultureInfo.GetCultureInfo("fa-IR");
        CultureInfo.DefaultThreadCurrentCulture = fa;
        CultureInfo.DefaultThreadCurrentUICulture = fa;

        // MudBlazor UI kit (same as the web host)
        builder.Services.AddMudServices(config =>
        {
            config.SnackbarConfiguration.PositionClass = Defaults.Classes.Position.BottomStart;
            config.SnackbarConfiguration.NewestOnTop = true;
            config.SnackbarConfiguration.ShowCloseIcon = true;
            config.SnackbarConfiguration.VisibleStateDuration = 3500;
            config.SnackbarConfiguration.PreventDuplicates = false;
        });

        // One memory-only object is both the remote authenticator and the SQL
        // provider. Register it before shared services so the configuration-
        // backed provider is never constructed in MAUI.
        builder.Services.AddSingleton<RemoteCredentialSession>();
        builder.Services.AddSingleton<ISqlConnectionProvider>(sp => sp.GetRequiredService<RemoteCredentialSession>());
        builder.Services.AddSingleton<IRemoteAuthenticationService>(sp => sp.GetRequiredService<RemoteCredentialSession>());
        builder.Services.AddSingleton<ICredentialSessionRevoker>(sp => sp.GetRequiredService<RemoteCredentialSession>());

        // Shared business services and existing direct-SQL operations.
        builder.Services.AddTarazinUiServices();

        

        return builder.Build();
    }
}
