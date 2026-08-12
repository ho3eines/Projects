using Microsoft.Extensions.DependencyInjection;

namespace Tarazin.Services;

/// <summary>
/// Registers the shared Tarazin services. Called by BOTH hosts:
///   - Tarazin.Web  (Blazor Server web app) — Program.cs
///   - Tarazin.Maui (MAUI Blazor Hybrid app) — MauiProgram.cs
///
/// Host-specific things (AddServerSideBlazor / AddMauiBlazorWebView,
/// MudBlazor providers, configuration source) are the host's job.
/// </summary>
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddTarazinSharedServices(this IServiceCollection services)
    {
        services.AddSingleton<ScriptCatalog>();   // self-loads embedded scripts
        services.AddScoped<DbService>();
        services.AddScoped<AuditService>();
        services.AddScoped<AuthService>();
        services.AddScoped<UserSession>();
        return services;
    }
}
