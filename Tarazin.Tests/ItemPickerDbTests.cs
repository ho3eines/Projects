using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// تست‌های دیتابیسی انتخاب کالا (ItemPickerCell/EntityPickerService):
    ///   ۱) ItemListLive — الحاق قیمت زندهٔ (OnlineRate) مرکز قیمت به لیست کالا
    ///   ۲) ItemUnits — ذخیرهٔ واحدهای چندگانه با ضریب تبدیل و واحد پیش‌فرض
    /// نیاز به SQL Server زنده دارد؛ اگر پیدا نشد Skip. الگو: InventoryPhase5Tests.
    /// </summary>
    public class ItemPickerDbTests
    {
        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

        private static string ConnString()
            => Environment.GetEnvironmentVariable("TARAZIN_TEST_CONN")
               ?? "Server=localhost;Database=TarazinMaster;User Id=sa;Password=123456;TrustServerCertificate=True";

        private static async Task<(SqlConnection cn, int companyId, int itemId)> SeedAsync(string key)
        {
            var cn = new SqlConnection(ConnString());
            await cn.OpenAsync();
            var companyId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست انتخاب کالا', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var itemId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Items (ItemCode, ItemTitle, Unit, UnitPrice, IsDeleted, CreatedAt, CompanyId, CreatedBy)
                VALUES (@Key, N'فلز تست', N'گرم', 0, 0, SYSUTCDATETIME(), @CompanyId, N'diag');
                SELECT SCOPE_IDENTITY();",
                new { Key = key, CompanyId = companyId });

            // اطلاعات مرکز قیمت: یک مادهٔ طلا با نرخ آنلاین معتبر
            var priceItemId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO currency.PriceItems (ItemKey, ItemType, Title, Unit, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (@Key, N'Metal', N'فلز تست', N'گرم', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();",
                new { Key = key });

            await cn.ExecuteAsync(@"
                INSERT INTO currency.PriceRates (PriceItemId, OnlineRate, SourceKey, IsValid, Status, LastFetchAt, RateDate, CreatedAt)
                VALUES (@PriceItemId, 221847730.0, N'TABLOTALA', 1, N'Active', SYSUTCDATETIME(), CAST(SYSUTCDATETIME() AS DATE), SYSUTCDATETIME());",
                new { PriceItemId = priceItemId });

            return (cn, companyId, itemId);
        }

        private static async Task CleanupAsync(SqlConnection cn, int companyId, string key)
        {
            try
            {
                // پاک‌سازی مرکز قیمت + کالا + شرکت
                await cn.ExecuteAsync(@"
                    DELETE pr FROM currency.PriceRates pr
                    JOIN currency.PriceItems pi ON pi.PriceItemId = pr.PriceItemId
                    WHERE pi.ItemKey = @Key;
                    DELETE FROM currency.PriceItems WHERE ItemKey = @Key;
                    DELETE FROM inventory.ItemUnits WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId = @CompanyId);
                    DELETE FROM inventory.Items WHERE CompanyId = @CompanyId;
                    DELETE FROM central.Companies WHERE CompanyId = @CompanyId;",
                    new { CompanyId = companyId, Key = key });
            }
            catch
            {
                // پاک‌سازی بهترین تلاش است
            }
            finally
            {
                await cn.DisposeAsync();
            }
        }

        [SkippableFact]
        public async Task ItemListLive_Joins_LiveOnlineRate_ByItemCode()
        {
            var key = $"XAU-18-TEST-{Guid.NewGuid():N}"[..20];
            var (cn, companyId, itemId) = await SeedAsync(key);
            try
            {
                // Act — لیست با قیمت زنده (همان چیزی که ItemPickerCell نمایش می‌دهد)
                var rows = await cn.QueryAsync(Script("ItemListLive.sql"), new { CompanyId = companyId, Search = key });
                var item = rows.FirstOrDefault(r => (string)r.ItemCode == key);

                Assert.NotNull(item);
                Assert.Equal(221847730.0m, (decimal)item.LivePrice);
                Assert.Equal("TABLOTALA", (string)item.LiveSource);
            }
            finally
            {
                await CleanupAsync(cn, companyId, key);
            }
        }

        [SkippableFact]
        public async Task ItemUnits_Upsert_StoresDefaultAndFactor()
        {
            var key = $"XAU-18-UNIT-{Guid.NewGuid():N}"[..20];
            var (cn, companyId, itemId) = await SeedAsync(key);
            try
            {
                // دو واحد: گرم (پیش‌فرض، Factor=1) + کیلوگرم (Factor=1000)
                var unitGram = await cn.ExecuteScalarAsync<int>(@"
                    INSERT INTO inventory.Units (UnitCode, Title, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                    VALUES (N'G', N'گرم', 1, 0, SYSUTCDATETIME(), N'diag', @CompanyId);
                    SELECT SCOPE_IDENTITY();", new { CompanyId = companyId });
                var unitKg = await cn.ExecuteScalarAsync<int>(@"
                    INSERT INTO inventory.Units (UnitCode, Title, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
                    VALUES (N'KG', N'کیلوگرم', 1, 0, SYSUTCDATETIME(), N'diag', @CompanyId);
                    SELECT SCOPE_IDENTITY();", new { CompanyId = companyId });

                var json = JsonSerializer.Serialize(new[]
                {
                    new { UnitId = unitGram, Factor = 1m, IsDefault = true },
                    new { UnitId = unitKg, Factor = 1000m, IsDefault = false }
                });

                // Act — ItemUnitsUpsert (همان چیزی که ItemDialog.SaveAsync صدا می‌زند)
                await cn.ExecuteAsync(Script("ItemUnitsUpsert.sql"),
                    new { ItemId = itemId, Json = json, CreatedBy = "diag" });

                // Assert — ItemUnitsList
                var units = (await cn.QueryAsync(Script("ItemUnitsList.sql"), new { ItemId = itemId })).ToList();
                Assert.Equal(2, units.Count);
                var gram = units.First(u => (int)u.UnitId == unitGram);
                var kg = units.First(u => (int)u.UnitId == unitKg);
                Assert.Equal(1m, (decimal)gram.Factor);
                Assert.True((bool)gram.IsDefault);
                Assert.Equal(1000m, (decimal)kg.Factor);
                Assert.False((bool)kg.IsDefault);
            }
            finally
            {
                await CleanupAsync(cn, companyId, key);
            }
        }

    }
}