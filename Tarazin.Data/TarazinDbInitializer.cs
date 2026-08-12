using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Tarazin.Data;

/// <summary>
/// One-time startup initialization shared by both hosts:
///   1. ensure schemas/tables (every <c>{schema}/_Ensure.sql</c>)
///   2. seed idempotently (every <c>{schema}/_Seed.sql</c>)
///   3. create the bootstrap admin when <c>[central].[Users]</c> is empty
///
/// Web host: called from Program.cs before <c>app.Run()</c>.
/// MAUI host: called from the shared <c>App.razor</c> OnInitializedAsync
/// (the Interlocked guard makes concurrent first-render calls safe).
/// </summary>
public static class TarazinDbInitializer
{
    private static int _initialized;

    public static async Task EnsureInitializedAsync(IServiceProvider services)
    {
        if (Interlocked.Exchange(ref _initialized, 1) == 1)
            return;

        try
        {
            var db = services.GetRequiredService<DbService>();
            var config = services.GetRequiredService<IConfiguration>();

            await db.EnsureSchemaAsync();
            await db.SeedAsync();
            await EnsureBootstrapAdminAsync(db, config);
        }
        catch
        {
            Interlocked.Exchange(ref _initialized, 0); // allow retry on next start
            throw;
        }
    }

    private static async Task EnsureBootstrapAdminAsync(DbService db, IConfiguration config)
    {
        var count = await db.ScalarAsync("central", "UserCount");
        if (count is not null && Convert.ToInt32(count) > 0)
            return;

        var username = config["Tarazin:BootstrapAdminUser"] ?? "admin";
        var password = config["Tarazin:BootstrapAdminPassword"] ?? "admin";

        await db.ExecuteAsync("central", "UserUpsert", new
        {
            UserId = 0,
            Username = username,
            PasswordHash = PasswordHasher.Hash(password),
            DisplayName = "مدیر سیستم",
            Role = "Admin",
            IsActive = true,
            CreatedBy = "bootstrap"
        });
    }
}
