using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Share.Services;

namespace Share.Extensions;

public class HermesOptions
{
    public string WebApiUrl { get; set; } = "https://localhost:65222";
}

public static class ServiceCollectionExtensions
{
    /// <summary>Registers ISystemApi → POST /api/system/{query|execute|scalar}.</summary>
    public static IServiceCollection AddHermesSystemApi(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<HermesOptions>(configuration.GetSection("Hermes"));
        services.AddHttpClient<ISystemApi, SystemApi>((sp, client) =>
        {
            var url = sp.GetRequiredService<IOptions<HermesOptions>>().Value.WebApiUrl;
            if (string.IsNullOrWhiteSpace(url))
                url = "https://localhost:65222";
            if (!url.EndsWith('/'))
                url += "/";
            client.BaseAddress = new Uri(url);
            client.Timeout = TimeSpan.FromSeconds(60);
        });
        return services;
    }
}
