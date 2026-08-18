using System.Text.Json;
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Tarazin.Models;

namespace Tarazin.Data;

/// <summary>
/// One-time server-side startup initialization:
///   1. ensure schemas/tables (every <c>{schema}/_Ensure.sql</c>)
///   2. seed idempotently (every <c>{schema}/_Seed.sql</c>)
///   3. create the bootstrap admin when <c>[central].[Users]</c> is empty
///
/// Only the Web host calls this. MAUI credentials never receive DDL, seed,
/// database-creation, or bootstrap permissions.
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

            // ۰. دیتابیس مقصد را در اولین اجرای هاست وب ایجاد کن. هیچ جزئیات
            //    provider یا رشتهٔ اتصالی وارد استثنای قابل ثبت در startup نمی‌شود.
            try
            {
                await db.EnsureDatabaseAsync();
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                throw new SafeDataException(DbService.Describe(ex));
            }

            // ۱. تست نهایی روی خودِ دیتابیس مقصد با خروجی کنترل‌شده.
            var check = await db.TestConnectionAsync();
            if (!check.Ok)
                throw new SafeDataException(check.Message);

            await db.EnsureSchemaAsync();
            await db.SeedAsync();
            await SyncAccessAsync(db);
            await EnsureBootstrapAdminAsync(db, config);
            // Apply RLS only after every schema and the control-plane tables
            // exist. This is idempotent and is never executed by MAUI.
            await db.ExecuteAsync("central", "_MobileSecurity");
        }
        catch (OperationCanceledException)
        {
            Interlocked.Exchange(ref _initialized, 0); // allow retry on next start
            throw;
        }
        catch (SafeDataException)
        {
            Interlocked.Exchange(ref _initialized, 0);
            throw;
        }
        catch (Exception ex)
        {
            Interlocked.Exchange(ref _initialized, 0);
            throw new SafeDataException(DbService.Describe(ex));
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
        {
            var existingUsername = config["Tarazin:BootstrapAdminUser"] ?? "admin";
            await db.ExecuteAsync("central", "EnsureAdminAccess", new { Username = existingUsername });
            return;
        }

        var username = config["Tarazin:BootstrapAdminUser"] ?? "admin";
        var password = config["Tarazin:BootstrapAdminPassword"];
        if (string.IsNullOrWhiteSpace(password))
            throw new SafeDataException(
                "رمز مدیر اولیه در secret store محیط استقرار تنظیم نشده است.");

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

        await db.ExecuteAsync("central", "EnsureAdminAccess", new { Username = username });
    }
}
