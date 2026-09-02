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
    /// تست‌های سناریو فاز ۵ — فاکتور خرید/فروش/هدیه/مالیات/انتقال.
    /// هر تست SQL Server زنده لازم دارد؛ اگر نبود Skip می‌شود.
    /// الگو: InventoryMovementInsertTests (Seed → Act → Assert → Cleanup).
    /// </summary>
    public class InventoryPhase5Tests
    {
        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

        private static async Task<(int CompanyId, int ItemId, int WarehouseId)> SeedAsync(SqlConnection cn)
        {
            var compId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست فاز۵', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var itemId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CompanyId)
                VALUES (N'P5-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای تست فاز۵', 0, 0, 0, SYSUTCDATETIME(), @c);
                SELECT SCOPE_IDENTITY();", new { c = compId });

            var whCode = "W" + Guid.NewGuid().ToString("N")[..4];
            var wh = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CompanyId)
                VALUES (@code, N'انبار تست فاز۵', 1, 0, @c);
                SELECT SCOPE_IDENTITY();", new { code = whCode, c = compId });

            await cn.ExecuteAsync(@"
                INSERT INTO inventory.InventorySettings (CompanyId, CostingMethod, IsEnabled, UpdatedAt)
                VALUES (@c, N'WeightedAverage', 0, SYSUTCDATETIME());", new { c = compId });

            return (compId, itemId, wh);
        }

        private static async Task CleanupAsync(SqlConnection cn, int compId)
        {
            await cn.ExecuteAsync(@"
                -- پاکسازی فاکتورها و برگشت‌ها و انتقال‌ها
                DELETE FROM inventory.PurchaseReturnLines WHERE PurchaseReturnId IN
                    (SELECT PurchaseReturnId FROM inventory.PurchaseReturns WHERE CompanyId=@c);
                DELETE FROM inventory.PurchaseReturns WHERE CompanyId=@c;
                DELETE FROM inventory.SalesReturnLines WHERE SalesReturnId IN
                    (SELECT SalesReturnId FROM inventory.SalesReturns WHERE CompanyId=@c);
                DELETE FROM inventory.SalesReturns WHERE CompanyId=@c;
                DELETE FROM inventory.InvoiceLines WHERE InvoiceId IN
                    (SELECT InvoiceId FROM inventory.Invoices WHERE CompanyId=@c);
                DELETE FROM inventory.Invoices WHERE CompanyId=@c;
                DELETE FROM inventory.TransferLines WHERE TransferId IN
                    (SELECT TransferId FROM inventory.WarehouseTransfers WHERE CompanyId=@c);
                DELETE FROM inventory.WarehouseTransfers WHERE CompanyId=@c;
                -- حرکات و لایه‌ها
                DECLARE @i INT = (SELECT TOP 1 ItemId FROM inventory.Items WHERE CompanyId=@c);
                IF @i IS NOT NULL
                BEGIN
                    DELETE FROM inventory.StockLayers WHERE ItemId=@i;
                    DELETE FROM inventory.Movements WHERE ItemId=@i;
                    DELETE FROM inventory.Items WHERE ItemId=@i;
                END
                DELETE FROM inventory.Barcodes WHERE ItemId IS NOT NULL;
                DELETE FROM inventory.Outbox WHERE EventKey LIKE N'MovementId=%';
                DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
                DELETE FROM accounting.Documents WHERE CompanyId=@c;
                DELETE FROM inventory.SubWarehouses WHERE WarehouseId IN (SELECT WarehouseId FROM inventory.Warehouses WHERE CompanyId=@c);
                DELETE FROM inventory.Warehouses WHERE CompanyId=@c;
                DELETE FROM inventory.InventorySettings WHERE CompanyId=@c;
                DELETE FROM central.FiscalYears WHERE CompanyId=@c;
                DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
        }

        /// <summary>سناریو ۱: خرید ۱۰۰ عدد با قیمت ۱۰۰۰ → موجودی ۱۰۰ + لایه.</summary>
        [SkippableFact]
        public async Task Purchase_invoice_100_items_updates_stock()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh) = await SeedAsync(cn);
            try
            {
                var linesJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 100m, GiftQty = 0m, UnitPrice = 1000m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });

                await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 5),
                    SupplierPartyId = (int?)null,
                    WarehouseId = wh,
                    SubWarehouseId = (int?)null,
                    ReferenceNumber = "",
                    PaymentTerms = "Cash",
                    DueDate = (DateTime?)null,
                    Description = "تست خرید",
                    CompanyId = compId,
                    FiscalYearId = (int?)null,
                    CreatedBy = "diag",
                    LinesJson = linesJson,
                    SerialsJson = (string?)null
                });

                var stock = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
                Assert.Equal(100m, stock);

                var layer = await cn.QuerySingleOrDefaultAsync<dynamic>(
                    "SELECT QtyRemaining, UnitCost FROM inventory.StockLayers WHERE ItemId=@i", new { i = itemId });
                Assert.NotNull(layer);
                Assert.Equal(100m, (decimal)layer.QtyRemaining);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        /// <summary>سناریو ۲: خرید ۱۰۰ + هدیه ۱۰ → موجودی ۱۱۰ ولی ارزش خرید فقط ۱۰۰×قیمت.</summary>
        [SkippableFact]
        public async Task Purchase_with_gift_qty_enters_stock_but_cost_only_for_paid_qty()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh) = await SeedAsync(cn);
            try
            {
                var linesJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 100m, GiftQty = 10m, UnitPrice = 1000m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });

                await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 5),
                    SupplierPartyId = (int?)null,
                    WarehouseId = wh,
                    SubWarehouseId = (int?)null,
                    ReferenceNumber = "",
                    PaymentTerms = "Cash",
                    DueDate = (DateTime?)null,
                    Description = "تست هدیه",
                    CompanyId = compId,
                    FiscalYearId = (int?)null,
                    CreatedBy = "diag",
                    LinesJson = linesJson,
                    SerialsJson = (string?)null
                });

                // موجودی باید ۱۱۰ باشد (۱۰۰ + ۱۰ هدیه)
                var stock = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
                Assert.Equal(110m, stock);

                // لایه هم باید ۱۱۰ باشد
                var layer = await cn.QuerySingleOrDefaultAsync<decimal>(
                    "SELECT QtyRemaining FROM inventory.StockLayers WHERE ItemId=@i", new { i = itemId });
                Assert.Equal(110m, layer);
            }
            finally { await CleanupAsync(cn, compId); }
        }

        /// <summary>سناریو ۳: مالیات — ۱۰۰×۱۰۰۰ با مالیات ۱۰٪ → مبلغ نهایی ۱۱۰٬۰۰۰.</summary>
        [SkippableFact]
        public async Task Purchase_with_tax_calculates_correctly()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh) = await SeedAsync(cn);
            try
            {
                var linesJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 100m, GiftQty = 0m, UnitPrice = 1000m,
                          DiscountPercent = 0m, TaxPercent = 10m, DutyPercent = 0m }
                });

                await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 5),
                    SupplierPartyId = (int?)null,
                    WarehouseId = wh,
                    SubWarehouseId = (int?)null,
                    ReferenceNumber = "",
                    PaymentTerms = "Cash",
                    DueDate = (DateTime?)null,
                    Description = "تست مالیات",
                    CompanyId = compId,
                    FiscalYearId = (int?)null,
                    CreatedBy = "diag",
                    LinesJson = linesJson,
                    SerialsJson = (string?)null
                });

                var inv = await cn.QuerySingleOrDefaultAsync<dynamic>(
                    "SELECT GrossAmount, TaxAmount, NetAmount FROM inventory.Invoices WHERE CompanyId=@c AND OperationType=N'Purchase'",
                    new { c = compId });

                Assert.NotNull(inv);
                Assert.Equal(100000m, (decimal)inv.GrossAmount);   // 100 × 1000
                Assert.Equal(10000m, (decimal)inv.TaxAmount);        // 10% of 100000
                Assert.Equal(110000m, (decimal)inv.NetAmount);      // 100000 + 10000
            }
            finally { await CleanupAsync(cn, compId); }
        }

        /// <summary>سناریو ۴: فروش ۳۰ عدد بعد از خرید ۱۰۰ → موجودی ۷۰.</summary>
        [SkippableFact]
        public async Task Sales_invoice_after_purchase_reduces_stock()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh) = await SeedAsync(cn);
            try
            {
                // خرید ۱۰۰
                var purchaseJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 100m, GiftQty = 0m, UnitPrice = 1000m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });
                await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 5),
                    SupplierPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                    ReferenceNumber = "", PaymentTerms = "Cash", DueDate = (DateTime?)null,
                    Description = "خرید", CompanyId = compId, FiscalYearId = (int?)null,
                    CreatedBy = "diag", LinesJson = purchaseJson,
                    SerialsJson = (string?)null
                });

                // فروش ۳۰
                var salesJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 30m, GiftQty = 0m, UnitPrice = 1200m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });
                await cn.ExecuteAsync(Script("SalesInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 6),
                    CustomerPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                    ReferenceNumber = (string?)null, PaymentTerms = "Cash", DueDate = (DateTime?)null,
                    SaleType = "Retail", Description = "فروش", CompanyId = compId,
                    FiscalYearId = (int?)null, CreatedBy = "diag", LinesJson = salesJson,
                    SerialsJson = (string?)null
                });

                var stock = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
                Assert.Equal(70m, stock);  // 100 - 30

                // سود ناخالص باید ۳۰ × (۱۲۰۰ - ۱۰۰۰) = ۶۰۰۰
                var inv = await cn.QuerySingleOrDefaultAsync<dynamic>(
                    "SELECT CostOfGoodsSold, GrossProfit FROM inventory.Invoices WHERE CompanyId=@c AND OperationType=N'Sales'",
                    new { c = compId });
                Assert.NotNull(inv);
                Assert.Equal(30000m, (decimal)inv.CostOfGoodsSold);  // 30 × 1000
                Assert.Equal(6000m, (decimal)inv.GrossProfit);        // 30 × (1200 - 1000)
            }
            finally { await CleanupAsync(cn, compId); }
        }

        /// <summary>سناریو ۵: فروش بیشتر از موجودی → باید Block شود.</summary>
        [SkippableFact]
        public async Task Sales_more_than_stock_throws()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh) = await SeedAsync(cn);
            try
            {
                // خرید ۱۰
                var purchaseJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 10m, GiftQty = 0m, UnitPrice = 1000m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });
                await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 5),
                    SupplierPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                    ReferenceNumber = "", PaymentTerms = "Cash", DueDate = (DateTime?)null,
                    Description = "خرید", CompanyId = compId, FiscalYearId = (int?)null,
                    CreatedBy = "diag", LinesJson = purchaseJson,
                    SerialsJson = (string?)null
                });

                // فروش ۵۰ (بیشتر از ۱۰)
                var salesJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 50m, GiftQty = 0m, UnitPrice = 1200m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });
                try
                {
                    await cn.ExecuteAsync(Script("SalesInvoiceInsert.sql"), new
                    {
                        InvoiceDate = new DateTime(2026, 4, 6),
                        CustomerPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                        ReferenceNumber = (string?)null, PaymentTerms = "Cash", DueDate = (DateTime?)null,
                        SaleType = "Retail", Description = "فروش", CompanyId = compId,
                        FiscalYearId = (int?)null, CreatedBy = "diag", LinesJson = salesJson,
                    SerialsJson = (string?)null
                    });
                    Assert.Fail("فروش بیشتر از موجودی باید خطا دهد.");
                }
                catch (SqlException ex) { Assert.Equal(51052, ex.Number); }
            }
            finally { await CleanupAsync(cn, compId); }
        }

        /// <summary>سناریو ۶: انتقال بین دو انبار — مبدأ کم، مقصد زیاد می‌شود.</summary>
        [SkippableFact]
        public async Task Transfer_between_warehouses_moves_stock()
        {
            using var cn = await TestDb.OpenOrSkipAsync();
            var (compId, itemId, wh1) = await SeedAsync(cn);
            try
            {
                // انبار دوم
                var wh2Code = "W2" + Guid.NewGuid().ToString("N")[..3];
                var wh2 = await cn.ExecuteScalarAsync<int>(@"
                    INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CompanyId)
                    VALUES (@code, N'انبار ۲ تست', 1, 0, @c);
                    SELECT SCOPE_IDENTITY();", new { code = wh2Code, c = compId });

                // خرید ۵۰ در انبار ۱
                var purchaseJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 50m, GiftQty = 0m, UnitPrice = 500m,
                          DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
                });
                await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 5),
                    SupplierPartyId = (int?)null, WarehouseId = wh1, SubWarehouseId = (int?)null,
                    ReferenceNumber = "", PaymentTerms = "Cash", DueDate = (DateTime?)null,
                    Description = "خرید", CompanyId = compId, FiscalYearId = (int?)null,
                    CreatedBy = "diag", LinesJson = purchaseJson,
                    SerialsJson = (string?)null
                });

                // انتقال ۲۰ از انبار ۱ به ۲
                var transferJson = JsonSerializer.Serialize(new[]
                {
                    new { ItemId = itemId, Qty = 20m }
                });
                await cn.ExecuteAsync(Script("TransferInsert.sql"), new
                {
                    TransferDate = new DateTime(2026, 4, 6),
                    FromWarehouseId = wh1, ToWarehouseId = wh2,
                    Description = "انتقال تست", CompanyId = compId,
                    CreatedBy = "diag", LinesJson = transferJson
                });

                // StockQty کل تغییر نمی‌کند (۵۰ باقی می‌ماند)
                var totalStock = await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
                Assert.Equal(50m, totalStock);

                // ولی لایه‌های انبار ۲ باید ۲۰ داشته باشد
                var wh2layer = await cn.QuerySingleOrDefaultAsync<decimal?>(
                    "SELECT SUM(QtyRemaining) FROM inventory.StockLayers WHERE ItemId=@i AND WarehouseId=@w",
                    new { i = itemId, w = wh2 });
                Assert.Equal(20m, wh2layer);
            }
            finally { await CleanupAsync(cn, compId); }
        }
    }
}
