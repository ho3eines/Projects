using Microsoft.Extensions.DependencyInjection;

namespace Tarazin.Data;

/// <summary>
/// Registers the **data layer** services. Called from the UI layer's
/// <c>AddTarazinUiServices</c> (which both hosts call), so hosts only ever
/// reference the UI registration.
/// </summary>
public static class DataServiceCollectionExtensions
{
    public static IServiceCollection AddTarazinDataServices(this IServiceCollection services)
    {
        services.AddSingleton<ScriptCatalog>();   // self-loads embedded scripts
        services.AddScoped<DbService>();
        services.AddScoped<AuditService>();
        return services;
    }
}
