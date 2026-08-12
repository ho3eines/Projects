using BlazorDeployService.Models;
using BlazorDeployService.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace BlazorDeployService.Extensions
{
    public static class ServiceCollectionExtensions
    {
        /// <summary>
        /// این سرویس برای اجرای سرویس ها مورد استفاده قرار میگیرد
        /// </summary>
        public static IServiceCollection AddBlazorDeployServices(this IServiceCollection services, IConfiguration configuration)
                {
                    services.Configure<AppSettings>(configuration.GetSection("BlazorDeploy"));

                    services.AddScoped<IAlertService, AlertService>();
                    services.AddScoped<IErrorDisplayService, ErrorDisplayService>();
                    services.AddScoped<IClientStorageService,ClientStorageService>();
                    services.AddScoped<IClientIdService, ClientIdService>();
                    services.AddScoped<ICultureService,CultureService>();
                    services.AddScoped<IEncryptionService, EncryptionService>();
                    services.AddScoped<ILocalizationCacheService,LocalizationCacheService>();
                    services.AddScoped<IThemeService,ThemeService>();
                    services.AddScoped<ISessionService, SessionService>();
                    services.AddScoped<IAuthService, AuthService>();
                    services.AddScoped<IRequestService,RequestService>();
                    services.AddScoped<IModalService, ModalService>();
                    services.AddScoped<ISqlService, SqlService>();
                    return services;
                }

        /// <summary>
        /// این سرویس برای اجرای سرویس ها مورد استفاده قرار میگیرد
        /// </summary>
        public static IServiceCollection AddBlazorDeployServices(this IServiceCollection services)
                {
                    services.AddScoped<IAlertService, AlertService>();
                    services.AddScoped<IErrorDisplayService, ErrorDisplayService>();
                    services.AddScoped<IClientStorageService, ClientStorageService>();
                    services.AddScoped<IClientIdService, ClientIdService>();
                    services.AddScoped<ICultureService, CultureService>();
                    services.AddScoped<IEncryptionService, EncryptionService>();
                    services.AddScoped<ILocalizationCacheService, LocalizationCacheService>();
                    services.AddScoped<IThemeService, ThemeService>();
                    services.AddScoped<ISessionService, SessionService>();
                    services.AddScoped<IAuthService, AuthService>();
                    services.AddScoped<IRequestService, RequestService>();
                    services.AddScoped<IModalService, ModalService>();
                    services.AddScoped<ISqlService, SqlService>();
                    return services;
                }

        //private static async Task InitializeServices(WebAssemblyHost host)
        //{
        //    try
        //    {
        //        // مقداردهی اولیه ClientIdService
        //        var clientIdService = host.Services.GetRequiredService<IClientIdService>();
        //        if (clientIdService is ClientIdService service)
        //        {
        //            await service.InitializeAsync();

        //            // گوش دادن به رویداد پاک شدن storage
        //            service.StorageCleared += (sender, e) =>
        //            {
        //                Console.WriteLine($"Storage was cleared: {e.Reason} at {e.ClearedAt}");
        //                // می‌توانید notify به کاربر یا ارسال به سرور
        //            };
        //        }

        //        Console.WriteLine("Services initialized successfully");
        //    }
        //    catch (Exception ex)
        //    {
        //        Console.WriteLine($"Error initializing services: {ex.Message}");
        //    }
        //}
    }
}
