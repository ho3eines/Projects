using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// Guard kompatibilitas parameter — skrip invoice harus tetap bekerja ketika
/// dipanggil TANPA parameter @SerialsJson (panggilan gaya lama yang hanya
/// mengirim @LinesJson). Ini mengunci kompatibilitas mundur untuk pemanggil
/// lama (telegram agent, skrip diag, integrasi pihak ketiga).
///
/// Skenario:
/// 1. PurchaseInvoiceInsert TANPA parameter @SerialsJson sama sekali → invoice,
///    baris, dan lapisan stok tetap tercatat, tanpa LotSerials.
/// 2. SalesInvoiceInsert TANPA @SerialsJson untuk item berserial → berhasil
///    (stok cukup), tidak melempar kesalahan.
/// </summary>
public class InvoiceLegacyParamGuardTests
{
    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

    private static async Task<(int CompanyId, int ItemId, int WarehouseId)> SeedAsync(SqlConnection cn)
    {
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست سازگاری', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var itemId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CompanyId, HasSerial)
            VALUES (N'LEG-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای سازگاری', 0, 0, 0, SYSUTCDATETIME(), @c, 1);
            SELECT SCOPE_IDENTITY();", new { c = compId });

        var whCode = "W" + Guid.NewGuid().ToString("N")[..4];
        var wh = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CompanyId)
            VALUES (@code, N'انبار سازگاری', 1, 0, @c);
            SELECT SCOPE_IDENTITY();", new { code = whCode, c = compId });

        await cn.ExecuteAsync(@"
            INSERT INTO inventory.InventorySettings (CompanyId, CostingMethod, IsEnabled, UpdatedAt)
            VALUES (@c, N'WeightedAverage', 0, SYSUTCDATETIME());", new { c = compId });

        return (compId, itemId, wh);
    }

    private static async Task CleanupAsync(SqlConnection cn, int compId)
    {
        await cn.ExecuteAsync(@"
            DELETE FROM inventory.InvoiceLines WHERE InvoiceId IN (SELECT InvoiceId FROM inventory.Invoices WHERE CompanyId=@c);
            DELETE FROM inventory.Invoices WHERE CompanyId=@c;
            DELETE FROM inventory.LotSerials WHERE CompanyId=@c;
            DELETE FROM inventory.StockLayers WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Movements WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Outbox WHERE EventKey LIKE N'MovementId=%';
            DELETE FROM inventory.Items WHERE CompanyId=@c;
            DELETE FROM inventory.SubWarehouses WHERE WarehouseId IN (SELECT WarehouseId FROM inventory.Warehouses WHERE CompanyId=@c);
            DELETE FROM inventory.Warehouses WHERE CompanyId=@c;
            DELETE FROM inventory.InventorySettings WHERE CompanyId=@c;
            DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
    }

    /// <summary>
    /// Gaya panggilan lama: TANPA @SerialsJson sama sekali (hanya @LinesJson).
    /// PurchaseInvoiceInsert harus tetap membuat invoice + baris + lapisan stok,
    /// dan tidak menyisakan LotSerials.
    /// </summary>
    [SkippableFact]
    public async Task Purchase_without_serials_param_still_inserts_invoice()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh) = await SeedAsync(cn);
        try
        {
            var linesJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 5m, GiftQty = 0m, UnitPrice = 500m,
                      DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
            });

            // PENTING: objek anonim mengirim SerialsJson = null (bukan properti
            // hilang) — pola proyek: semua parameter opsional dikirim dengan NULL.
            await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
            {
                InvoiceDate = new DateTime(2026, 4, 5),
                SupplierPartyId = (int?)null,
                WarehouseId = wh,
                SubWarehouseId = (int?)null,
                ReferenceNumber = "",
                PaymentTerms = "Cash",
                DueDate = (DateTime?)null,
                Description = "تست سازگاری بدون سریال",
                CompanyId = compId,
                FiscalYearId = (int?)null,
                CreatedBy = "diag",
                LinesJson = linesJson,
                SerialsJson = (string?)null
            });

            var invoice = await cn.QuerySingleAsync<dynamic>(
                "SELECT InvoiceNumber, NetAmount FROM inventory.Invoices WHERE CompanyId=@c",
                new { c = compId });
            Assert.NotNull((string)invoice.InvoiceNumber);

            var lineCount = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM inventory.InvoiceLines WHERE CompanyId=@c", new { c = compId });
            Assert.Equal(1, lineCount);

            var layer = await cn.QuerySingleOrDefaultAsync<dynamic>(
                "SELECT QtyRemaining FROM inventory.StockLayers WHERE CompanyId=@c", new { c = compId });
            Assert.NotNull(layer);
            Assert.Equal(5m, (decimal)layer.QtyRemaining);

            var serialCount = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM inventory.LotSerials WHERE CompanyId=@c", new { c = compId });
            Assert.Equal(0, serialCount);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    /// <summary>
    /// Gaya panggilan lama pada penjualan: TANPA @SerialsJson untuk item berserial.
    /// Stok cukup (dibeli 5 unit) → penjualan 2 unit harus berhasil tanpa melempar
    /// kesalahan parameter maupun 51055.
    /// </summary>
    [SkippableFact]
    public async Task Sales_without_serials_param_still_succeeds()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh) = await SeedAsync(cn);
        try
        {
            var buyLines = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 5m, GiftQty = 0m, UnitPrice = 500m,
                      DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
            });
            await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
            {
                InvoiceDate = new DateTime(2026, 4, 5),
                SupplierPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                ReferenceNumber = "", PaymentTerms = "Cash", DueDate = (DateTime?)null,
                Description = "تست سازگاری خرید", CompanyId = compId, FiscalYearId = (int?)null,
                CreatedBy = "diag", LinesJson = buyLines, SerialsJson = (string?)null
            });

            var sellLines = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 2m, GiftQty = 0m, UnitPrice = 800m,
                      DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
            });
            // SerialsJson = null — pola proyek untuk parameter opsional (Selalu kirim NULL).
            await cn.ExecuteAsync(Script("SalesInvoiceInsert.sql"), new
            {
                InvoiceDate = new DateTime(2026, 4, 6),
                CustomerPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                ReferenceNumber = (string?)null, PaymentTerms = "Cash", DueDate = (DateTime?)null,
                SaleType = "Retail", Description = "فروش بدون سریال", CompanyId = compId,
                FiscalYearId = (int?)null, CreatedBy = "diag",
                LinesJson = sellLines, SerialsJson = (string?)null
            });

            var invoice = await cn.QuerySingleAsync<dynamic>(
                "SELECT InvoiceNumber, NetAmount FROM inventory.Invoices WHERE CompanyId=@c AND OperationType=N'Sales'",
                new { c = compId });
            Assert.NotNull((string)invoice.InvoiceNumber);

            var remaining = await cn.ExecuteScalarAsync<decimal>(
                "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
            Assert.Equal(3m, remaining);
        }
        finally { await CleanupAsync(cn, compId); }
    }
}
