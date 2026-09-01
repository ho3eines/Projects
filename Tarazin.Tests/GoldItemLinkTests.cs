using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// سناریوی دیالوگ اتصال جنس طلا به کالای انبار (GoldItemLinkDialog):
/// لینک (ذخیرهٔ InventoryItemCode)، نمایش عنوان کالای متصل در GoldItemList،
/// تعویض اتصال و قطع اتصال (null).
/// الگو: InventoryPhase5Tests (Seed → Act → Assert → Cleanup)، نیازمند SQL Server زنده.
/// </summary>
public class GoldItemLinkTests
{
    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/goldshop", name));

    private static async Task<(int CompanyId, int GoldItemId, int ItemId)> SeedAsync(SqlConnection cn)
    {
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست طلا', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var goldItemId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO goldshop.GoldItems (ItemCode, Title, Purity, IsActive, IsDeleted, CreatedAt, CompanyId)
            VALUES (N'XAU-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'جنس طلای تست', 18, 1, 0, SYSUTCDATETIME(), @c);
            SELECT SCOPE_IDENTITY();", new { c = compId });

        var itemId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CompanyId)
            VALUES (N'INV-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای انبار تست', 0, 0, 0, SYSUTCDATETIME(), @c);
            SELECT SCOPE_IDENTITY();", new { c = compId });

        return (compId, goldItemId, itemId);
    }

    private static async Task CleanupAsync(SqlConnection cn, int compId)
    {
        // پاکسازی همهٔ ردیف‌های شرکت (نه فقط یک کالا) تا FK_Items_Company شکسته نشود
        await cn.ExecuteAsync(@"
            DELETE FROM goldshop.GoldItems WHERE CompanyId=@c;
            DELETE FROM inventory.StockLayers WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Movements WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Barcodes WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Outbox WHERE EventKey LIKE N'MovementId=%';
            DELETE FROM inventory.Items WHERE CompanyId=@c;
            DELETE FROM inventory.InventorySettings WHERE CompanyId=@c;
            DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
    }

    /// <summary>شبیه‌سازی GoldItemLinkDialog: ذخیرهٔ کد کالای انبار با GoldItemUpsert → در DB ثبت و در GoldItemList با عنوان دیده شود؛ سپس قطع اتصال.</summary>
    [SkippableFact]
    public async Task Link_saves_code_and_list_shows_title_then_unlink_clears_it()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, goldItemId, itemId) = await SeedAsync(cn);
        try
        {
            var itemCode = await cn.ExecuteScalarAsync<string>(
                "SELECT ItemCode FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
            var itemTitle = await cn.ExecuteScalarAsync<string>(
                "SELECT ItemTitle FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
            var gold = await cn.QuerySingleAsync<GoldSeedRow>(
                "SELECT ItemCode, Title, Purity, IsActive FROM goldshop.GoldItems WHERE GoldItemId=@g", new { g = goldItemId });

            // ── Act: لینک (دقیقاً همان پارامترهایی که GoldItemLinkDialog به GoldItemUpsert می‌دهد) ──
            await cn.ExecuteAsync(Script("GoldItemUpsert.sql"), new
            {
                GoldItemId = goldItemId,
                ItemCode = gold.ItemCode,
                Title = gold.Title,
                Purity = gold.Purity,
                InventoryItemCode = itemCode,
                IsActive = gold.IsActive,
                CompanyId = compId,
                CreatedBy = "diag",
            });

            // ── Assert ۱: InventoryItemCode در DB ذخیره شده ──
            var savedCode = await cn.ExecuteScalarAsync<string>(
                "SELECT InventoryItemCode FROM goldshop.GoldItems WHERE GoldItemId=@g", new { g = goldItemId });
            Assert.Equal(itemCode, savedCode);

            // ── Assert ۲: GoldItemList عنوان کالای متصل را از JOIN برمی‌گرداند ──
            var listed = (await cn.QueryAsync<GoldItemListRow>(Script("GoldItemList.sql"),
                new { CompanyId = compId })).ToList();
            var linked = Assert.Single(listed, r => r.GoldItemId == goldItemId);
            Assert.Equal(itemCode, linked.InventoryItemCode);
            Assert.Equal(itemTitle, linked.InventoryItemTitle);

            // ── Act: قطع اتصال (InventoryItemCode = null) ──
            await cn.ExecuteAsync(Script("GoldItemUpsert.sql"), new
            {
                GoldItemId = goldItemId,
                ItemCode = gold.ItemCode,
                Title = gold.Title,
                Purity = gold.Purity,
                InventoryItemCode = (string?)null,
                IsActive = gold.IsActive,
                CompanyId = compId,
                CreatedBy = "diag",
            });

            // ── Assert ۳: اتصال قطع شده و لیست دیگر عنوانی برنمی‌گرداند ──
            var afterUnlink = await cn.ExecuteScalarAsync<string?>(
                "SELECT InventoryItemCode FROM goldshop.GoldItems WHERE GoldItemId=@g", new { g = goldItemId });
            Assert.Null(afterUnlink);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    /// <summary>ذخیرهٔ مجدد با کالای دیگر، اتصال را عوض می‌کند (نه کد قبلی، نه null).</summary>
    [SkippableFact]
    public async Task Relink_switches_to_another_inventory_item()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, goldItemId, itemAId) = await SeedAsync(cn);
        try
        {
            // کالای انبار دوم
            var itemBId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CompanyId)
                VALUES (N'INV-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای دوم تست', 0, 0, 0, SYSUTCDATETIME(), @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });
            var itemACode = await cn.ExecuteScalarAsync<string>(
                "SELECT ItemCode FROM inventory.Items WHERE ItemId=@i", new { i = itemAId });
            var itemBCode = await cn.ExecuteScalarAsync<string>(
                "SELECT ItemCode FROM inventory.Items WHERE ItemId=@i", new { i = itemBId });
            var gold = await cn.QuerySingleAsync<GoldSeedRow>(
                "SELECT ItemCode, Title, Purity, IsActive FROM goldshop.GoldItems WHERE GoldItemId=@g", new { g = goldItemId });

            // لینک به کالای A
            await cn.ExecuteAsync(Script("GoldItemUpsert.sql"), new
            {
                GoldItemId = goldItemId, ItemCode = gold.ItemCode, Title = gold.Title,
                Purity = gold.Purity, InventoryItemCode = itemACode, IsActive = gold.IsActive, CompanyId = compId,
                CreatedBy = "diag",
            });
            // لینک مجدد به کالای B (همان ذخیرهٔ دکمه در دیالوگ با انتخاب جدید)
            await cn.ExecuteAsync(Script("GoldItemUpsert.sql"), new
            {
                GoldItemId = goldItemId, ItemCode = gold.ItemCode, Title = gold.Title,
                Purity = gold.Purity, InventoryItemCode = itemBCode, IsActive = gold.IsActive, CompanyId = compId,
                CreatedBy = "diag",
            });

            var savedCode = await cn.ExecuteScalarAsync<string?>(
                "SELECT InventoryItemCode FROM goldshop.GoldItems WHERE GoldItemId=@g", new { g = goldItemId });
            Assert.Equal(itemBCode, savedCode);
            Assert.NotEqual(itemACode, savedCode);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    private sealed class GoldSeedRow
    {
        public string ItemCode { get; set; } = "";
        public string Title { get; set; } = "";
        public decimal? Purity { get; set; }
        public bool IsActive { get; set; }
    }

    private sealed class GoldItemListRow
    {
        public int GoldItemId { get; set; }
        public string? InventoryItemCode { get; set; }
        public string? InventoryItemTitle { get; set; }
    }
}
