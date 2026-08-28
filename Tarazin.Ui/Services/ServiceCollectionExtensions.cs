using Microsoft.Extensions.DependencyInjection;
using Tarazin.Data;

namespace Tarazin.Services;

/// <summary>
/// Registers the **UI-layer** services (session, auth) plus the whole data
/// layer. Called by BOTH hosts:
///   - Tarazin.Web  (Blazor Server web app) — Program.cs
///   - Tarazin.Maui (MAUI Blazor Hybrid app) — MauiProgram.cs
///
/// Host-specific things (AddServerSideBlazor / AddMauiBlazorWebView,
/// MudBlazor providers, configuration source) are the host's job.
/// </summary>
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddTarazinUiServices(this IServiceCollection services)
    {
        // Data layer (DbService, ScriptCatalog, AuditService)
        services.AddTarazinDataServices();

        // UI-layer services
        services.AddScoped<UserSession>();
        services.AddScoped<UiPreferences>();
        services.AddScoped<ICurrentUser>(sp => sp.GetRequiredService<UserSession>());
        services.AddScoped<AuthService>();
        services.AddScoped<UserService>();
        services.AddScoped<AccountingContextService>();
        services.AddScoped<EntityCrudService>();
        services.AddScoped<BiReportService>();   // چاپ و گزارش با Stimulsoft (BI)
        services.AddScoped<AccountPickerService>(); // انتخاب حساب (Account Picker)

        // PDF سمت سرور (QuestPDF) — موتور مشترک وب + MAUI. ذخیره‌کننده (IPdfSaver)
        // را هاست ثبت می‌کند (وب: WebPdfSaver، MAUI: MauiPdfSaver).
        services.AddScoped<PdfReportService>();

        return services;
    }
}
