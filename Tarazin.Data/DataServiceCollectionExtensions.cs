using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Tarazin.Data.Services;

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
        services.TryAddScoped<ISqlConnectionProvider, ConfigurationSqlConnectionProvider>();
        services.AddScoped<DbService>();
        services.AddScoped<AuditService>();

        // ماژول ارز: دریافت آنلاین نرخ (PRD §44/§56/§58/§61) — دادهٔ بازار خارجی
        // از API/Feed رسمی منابع تعریف‌شده؛ هرگز جایگزین مسیر Dapper برای دادهٔ
        // کسب‌وکار نمی‌شود.
        services.AddScoped<PriceFeedService>();
        services.AddSingleton<PriceFeedScheduler>();

        // حقوق و دستمزد
        services.AddScoped<PayrollTaxService>();
        services.AddScoped<PayrollCalculationService>();

        // دیسپچر پس‌زمینهٔ Outbox حقوق (تخلیهٔ PayrollFinalized → accounting/treasury)
        services.AddSingleton<PayrollOutboxDispatcher>();

        return services;
    }
}
