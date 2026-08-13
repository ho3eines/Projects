using System.Text.Json;
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Tarazin.Models;

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

            // ۰. دیتابیس مقصد را در اولین اجرا بساز (SQL Server تازه/کانتینر خالی).
            //    این کار با اتصال به master انجام می‌شود، پس اگر خودِ سرور در
            //    دسترس نباشد همین‌جا با پیام فارسی گویا شکست می‌خورد.
            try
            {
                await db.EnsureDatabaseAsync();
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException(
                    $"اتصال به SQL Server برقرار نشد. {DbService.Describe(ex)}{Environment.NewLine}" +
                    $"رشتهٔ اتصال: {db.MaskedConnectionString}", ex);
            }

            // ۱. تست نهایی روی خودِ دیتابیس مقصد.
            var check = await db.TestConnectionAsync();
            if (!check.Ok)
                throw new InvalidOperationException(
                    $"اتصال به دیتابیس مقصد برقرار نشد. {check.Message}{Environment.NewLine}" +
                    $"رشتهٔ اتصال: {check.MaskedConnectionString}");

            await db.EnsureSchemaAsync();
            await db.SeedAsync();
            await SyncAccessAsync(db);
            await EnsureBootstrapAdminAsync(db, config);
        }
        catch
        {
            Interlocked.Exchange(ref _initialized, 0); // allow retry on next start
            throw;
        }
    }

    /// <summary>
    /// همگام‌سازی RBAC از کاتالوگ C# به دیتابیس (idempotent):
    /// دسترسی‌ها، نقش‌های پیش‌فرض و نگاشت نقش→دسترسی. سپس RoleId
    /// کاربران قدیمی (که فقط Role رشته‌ای داشتند) پر می‌شود.
    /// </summary>
    private static async Task SyncAccessAsync(DbService db)
    {
        // JSON دسترسی‌ها/نقش‌ها می‌تواند بزرگ باشد؛ برای جلوگیری از خطای
        // «رشته باینری کوتاه‌تر از حد» آن را صریحاً nvarchar(max) ارسال می‌کنیم.
        var permissionsJson = JsonSerializer.Serialize(
            TarazinPermissions.All.Select(p => new { key = p.Key, title = p.Title, module = p.ModuleKey }));
        await db.ExecuteAsync("central", "PermissionSync", new
        {
            PermissionsJson = new DbString { Value = permissionsJson, IsAnsi = false, Length = -1 }
        });

        var rolesJson = JsonSerializer.Serialize(
            TarazinRoles.Defaults.Select(r => new
            {
                key = r.Key,
                title = r.Title,
                description = r.Description,
                isSystem = r.IsSystem
            }));
        await db.ExecuteAsync("central", "RoleSync", new
        {
            RolesJson = new DbString { Value = rolesJson, IsAnsi = false, Length = -1 }
        });

        foreach (var role in TarazinRoles.Defaults)
        {
            var rolePermissionsJson = JsonSerializer.Serialize(role.Permissions);
            await db.ExecuteAsync("central", "RolePermissionSync", new
            {
                RoleKey = role.Key,
                PermissionsJson = new DbString { Value = rolePermissionsJson, IsAnsi = false, Length = -1 }
            });
        }

        await db.ExecuteAsync("central", "UserRoleBackfill");
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
