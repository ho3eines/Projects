using System;
using System.IO;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// گاردِ بازگشت‌پذیر روی مسیر «ثبت حرکت انبار» (inventory.MovementInsert — REAL).
    /// همان مسیری که فرم «ثبت حرکت انبار» (InventoryEntry) با دکمهٔ «ثبت حرکت» صدا می‌زند:
    ///  - رسید: ثبت حرکت MV-….، افزودن لایهٔ موجودی، به‌روزرسانی StockQty و رویداد Outbox.
    ///  - خروج بدون موجودی → خطای 51003 «موجودی کافی نیست».
    ///  - کالای ناموجود → 51002؛ نوعِ حرکت نامعتبر → 51006.
    /// نیازمند SQL Server زنده است؛ اگر در دسترس نبود تست Skip می‌شود.
    /// </summary>
    public class InventoryMovementInsertTests
    {
        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

        private static async Task<(int CompanyId, int ItemId, int WarehouseId, int SubWarehouseId)> SeedAsync(SqlConnection cn)
        {
            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست انبار', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var itemId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt)
                VALUES (N'ITEST-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای تست', 0, 0, 0, SYSUTCDATETIME());
                SELECT SCOPE_IDENTITY();");

            var whCode = "W" + Guid.NewGuid().ToString("N")[..4];
            var wh = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CompanyId)
                VALUES (@code, N'انبار تست', 1, 0, @c);
                SELECT SCOPE_IDENTITY();", new { code = whCode, c = compId });
            var whId = (int)wh;

            var subCode = "SW" + Guid.NewGuid().ToString("N")[..4];
            var sub = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.SubWarehouses (WarehouseId, SubWarehouseCode, Title, IsActive, IsDeleted, CreatedAt)
                VALUES (@w, @code, N'انبارک تست', 1, 0, SYSUTCDATETIME());
                SELECT SCOPE_IDENTITY();", new { w = whId, code = subCode });

            // تنظیمات انبار: IsEnabled=0 تا سند حسابداریِ خودکار درگیر نشود (تستِ خالصِ موجودی)
            await cn.ExecuteAsync(@"
                INSERT INTO inventory.InventorySettings (CompanyId, CostingMethod, IsEnabled, UpdatedAt)
                VALUES (@c, N'WeightedAverage', 0, SYSUTCDATETIME());", new { c = compId });

            return (compId, itemId, wh, sub);
        }

        private static async Task CleanupAsync(SqlConnection cn, int compId)
        {
            // حذف item هم ردیف‌های Movements/StockLayers/Outbox را با FK cascade نمی‌کند؛ دستی.
            await cn.ExecuteAsync(@"
                DECLARE @i INT = (SELECT TOP 1 ItemId FROM inventory.Items WHERE ItemId IN
                                  (SELECT ItemId FROM inventory.Movements WHERE CompanyId=@c));
                IF @i IS NOT NULL
                BEGIN
                    DELETE FROM inventory.StockLayers WHERE ItemId=@i;
                    DELETE FROM inventory.Movements WHERE ItemId=@i;
                    DELETE FROM inventory.Items WHERE ItemId=@i;
                END
                DELETE FROM inventory.Outbox WHERE EventKey LIKE N'MovementId=%';
                -- سند حسابداری خودکارِ حاصل از حرکت (اگر اتصال فعال بود)
                DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
                DELETE FROM accounting.Documents WHERE CompanyId=@c;
                DELETE FROM inventory.SubWarehouses WHERE WarehouseId IN (SELECT WarehouseId FROM inventory.Warehouses WHERE CompanyId=@c);
                DELETE FROM inventory.Warehouses WHERE CompanyId=@c;
                DELETE FROM inventory.InventorySettings WHERE CompanyId=@c;
                DELETE FROM central.FiscalYears WHERE CompanyId=@c;
                DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        }

        private static async Task<int> TryInvInsertAsync(
            SqlConnection cn, int compId, int itemId, int? wh, int? sub,
            string type, decimal qty, decimal unitPrice, int? fiscalYearId = null)
        {
            try
            {
                await cn.ExecuteAsync(Script("MovementInsert.sql"), new
                {
                    MovementType = type,
                    ItemId = itemId,
                    WarehouseId = wh,
                    SubWarehouseId = sub,
                    Qty = qty,
                    UnitPrice = unitPrice,
                    MovementDate = new DateTime(2026, 4, 5),
                    Description = "تست",
                    CreatedBy = "diag",
                    CompanyId = compId,
                    FiscalYearId = fiscalYearId
                });
                return -1;
            }
            catch (SqlException ex) { return ex.Number; }
        }

        [SkippableFact]
        public async Task Receipt_posts_updates_stock_layer_outbox()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh, sub) = await SeedAsync(cn);
            try
            {
                var rc = await TryInvInsertAsync(cn, compId, itemId, wh, sub, "Receipt", 27, 1000);
                Assert.Equal(-1, rc);

                var mv = await cn.QuerySingleOrDefaultAsync<dynamic>(@"
                    SELECT MovementNumber, MovementType, Qty, CostPrice, [Status]
                    FROM inventory.Movements WHERE ItemId=@i AND IsDeleted=0", new { i = itemId });
                Assert.NotNull(mv);
                Assert.StartsWith("MV-", (string)mv.MovementNumber);
                Assert.Equal("Receipt", (string)mv.MovementType);
                Assert.Equal(27m, (decimal)mv.Qty);
                Assert.Equal(1000m, (decimal)mv.CostPrice);
                Assert.Equal("Posted", (string)mv.Status);

                var stock = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
                Assert.Equal(27m, stock);

                var layer = await cn.QuerySingleOrDefaultAsync<dynamic>(@"
                    SELECT QtyRemaining, UnitCost FROM inventory.StockLayers WHERE ItemId=@i", new { i = itemId });
                Assert.NotNull(layer);
                Assert.Equal(27m, (decimal)layer.QtyRemaining);
                Assert.Equal(1000m, (decimal)layer.UnitCost);

                var outbox = await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM inventory.Outbox WHERE EventType=N'InventoryMovement'");
                Assert.True(outbox >= 1, "receipt must write an outbox event");
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task Issue_insufficient_stock_throws_51003()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh, sub) = await SeedAsync(cn);
            try
            {
                // ابتدا 27 عدد رسید، بعد خروج 100 → ناکافی
                Assert.Equal(-1, await TryInvInsertAsync(cn, compId, itemId, wh, sub, "Receipt", 27, 1000));
                var rc = await TryInvInsertAsync(cn, compId, itemId, wh, sub, "Issue", 100, 1000);
                Assert.Equal(51003, rc);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task Invalid_item_throws_51002()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, _, wh, sub) = await SeedAsync(cn);
            try
            {
                var rc = await TryInvInsertAsync(cn, compId, 99999999, wh, sub, "Receipt", 1, 10);
                Assert.Equal(51002, rc);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task Receipt_with_accounting_enabled_creates_auto_document()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh, sub) = await SeedAsync(cn);
            try
            {
                var fyId = await cn.ExecuteScalarAsync<int>(@"
                    INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, [Status], CreatedAt, CreatedBy)
                    VALUES (@c, N'1405', '2026-03-21', '2027-03-20', 1, N'Open', SYSUTCDATETIME(), N'diag');
                    SELECT SCOPE_IDENTITY();", new { c = compId });

                // فعال‌سازی اتصال حسابداری + تنظیم حساب انبار و حساب مقابل
                await cn.ExecuteAsync(Script("InventorySettingsUpsert.sql"), new
                {
                    CompanyId = compId,
                    CostingMethod = "WeightedAverage",
                    InventoryAccountId = 9001,
                    InventoryAccountCode = "1101",
                    InventoryAccountTitle = "حساب انبار",
                    ReceiptContraAccountId = 9002,
                    ReceiptContraAccountCode = "5101",
                    ReceiptContraAccountTitle = "حساب مقابل رسید",
                    IssueContraAccountId = 9002,
                    IssueContraAccountCode = "5101",
                    IssueContraAccountTitle = "حساب مقابل حواله",
                    AdjustmentAccountId = (int?)null,
                    AdjustmentAccountCode = (string?)null,
                    AdjustmentAccountTitle = (string?)null,
                    DefaultWarehouseId = (int?)null,
                    DefaultSubWarehouseId = (int?)null,
                    IsEnabled = true,
                    UpdatedBy = "diag"
                });

                // رسید ۱۰ عدد × ۵۰۰ = ۵٬۰۰۰
                var rc = await TryInvInsertAsync(cn, compId, itemId, wh, sub, "Receipt", 10, 500, fyId);
                Assert.Equal(-1, rc);

                var doc = await cn.QuerySingleOrDefaultAsync<dynamic>(@"
                    SELECT DocumentType, TotalAmount, [Status], FiscalYearId, DocumentNumber
                    FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0", new { c = compId });

                Assert.NotNull(doc);
                Assert.Equal("InventoryReceipt", (string)doc.DocumentType);
                Assert.Equal(5000m, (decimal)doc.TotalAmount);
                Assert.Equal("Note", (string)doc.Status);
                Assert.Equal(fyId, (int)doc.FiscalYearId);
                Assert.StartsWith("0000000", (string)doc.DocumentNumber);

                // دو ردیف سند: بدهکار حساب انبار ۵٬۰۰۰ / بستانکار حساب مقابل ۵٬۰۰۰ (متوازن)
                var lines = (await cn.QueryAsync<dynamic>(@"
                    SELECT AccountCode, Title, Debit, Credit
                    FROM accounting.DocumentLines
                    WHERE DocumentId=(SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c AND IsDeleted=0)",
                    new { c = compId })).ToList();

                Assert.Equal(2, lines.Count);
                Assert.Contains(lines, l => l.Debit == 5000m && l.Credit == 0m && (string)l.AccountCode == "1101");
                Assert.Contains(lines, l => l.Credit == 5000m && l.Debit == 0m && (string)l.AccountCode == "5101");
            }
            finally { await CleanupAsync(cn, compId); }
        }

        [SkippableFact]
        public async Task Invalid_type_throws_51006()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh, sub) = await SeedAsync(cn);
            try
            {
                var rc = await TryInvInsertAsync(cn, compId, itemId, wh, sub, "Bogus", 1, 10);
                Assert.Equal(51006, rc);
            }
            finally { await CleanupAsync(cn, compId); }
        }
    }
}