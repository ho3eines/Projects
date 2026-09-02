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
/// سناریوی Batch/Serial/Expiry — ثبت سریال/بچ هنگام خرید (LotSerials Status=In)
/// و صدور هنگام فروش (Status=Out) + رد سریالِ قبلاً صادر شده.
/// الگو: InventoryPhase5Tests (Seed → Act → Assert → Cleanup).
/// </summary>
public class LotSerialTests
{
    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

    private static async Task<(int CompanyId, int ItemId, int WarehouseId)> SeedAsync(SqlConnection cn)
    {
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست سریال', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var itemId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CompanyId, HasSerial)
            VALUES (N'SER-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای سریالی تست', 0, 0, 0, SYSUTCDATETIME(), @c, 1);
            SELECT SCOPE_IDENTITY();", new { c = compId });

        var whCode = "W" + Guid.NewGuid().ToString("N")[..4];
        var wh = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CompanyId)
            VALUES (@code, N'انبار تست سریال', 1, 0, @c);
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

    /// <summary>خرید با سریال → ردیف‌های LotSerials با Status=In و پیوند به حرکت رسید ثبت می‌شوند.</summary>
    [SkippableFact]
    public async Task Purchase_with_serials_registers_in_stock()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh) = await SeedAsync(cn);
        try
        {
            var linesJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 2m, GiftQty = 0m, UnitPrice = 1000m,
                      DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
            });
            var serialsJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, LotNo = (string?)null, SerialNo = "S-1001", ExpiryDate = (DateTime?)null, Qty = 1m },
                new { ItemId = itemId, LotNo = (string?)null, SerialNo = "S-1002", ExpiryDate = (DateTime?)null, Qty = 1m }
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
                Description = "تست سریال",
                CompanyId = compId,
                FiscalYearId = (int?)null,
                CreatedBy = "diag",
                LinesJson = linesJson,
                SerialsJson = serialsJson
            });

            var serials = (await cn.QueryAsync<dynamic>(
                "SELECT SerialNo, Status, ReceiptMovementId, WarehouseId FROM inventory.LotSerials WHERE CompanyId=@c",
                new { c = compId })).ToList();
            Assert.Equal(2, serials.Count);
            Assert.All(serials, s => Assert.Equal("In", (string)s.Status));
            Assert.All(serials, s => Assert.Equal(wh, (int)s.WarehouseId));
            Assert.All(serials, s => Assert.NotNull((int?)s.ReceiptMovementId));
            Assert.Contains(serials, s => (string)s.SerialNo == "S-1001");
            Assert.Contains(serials, s => (string)s.SerialNo == "S-1002");
        }
        finally { await CleanupAsync(cn, compId); }
    }

    /// <summary>فروش با همان سریال‌ها → Status=Out و IssueMovementId ست می‌شود؛ سریالِ صادرشده دیگر In نیست.</summary>
    [SkippableFact]
    public async Task Sales_issues_serials_as_out()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh) = await SeedAsync(cn);
        try
        {
            var linesJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 1m, GiftQty = 0m, UnitPrice = 1200m,
                      DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
            });
            var serialsJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, LotNo = (string?)null, SerialNo = "S-2001", ExpiryDate = (DateTime?)null, Qty = 1m }
            });

            // خرید سریال S-2001
            await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
            {
                InvoiceDate = new DateTime(2026, 4, 5),
                SupplierPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                ReferenceNumber = "", PaymentTerms = "Cash", DueDate = (DateTime?)null,
                Description = "خرید سریال", CompanyId = compId, FiscalYearId = (int?)null,
                CreatedBy = "diag", LinesJson = linesJson, SerialsJson = serialsJson
            });

            // فروش همان سریال
            await cn.ExecuteAsync(Script("SalesInvoiceInsert.sql"), new
            {
                InvoiceDate = new DateTime(2026, 4, 6),
                CustomerPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                ReferenceNumber = (string?)null, PaymentTerms = "Cash", DueDate = (DateTime?)null,
                SaleType = "Retail", Description = "فروش سریال", CompanyId = compId,
                FiscalYearId = (int?)null, CreatedBy = "diag",
                LinesJson = linesJson, SerialsJson = serialsJson
            });

            var row = await cn.QuerySingleAsync<dynamic>(
                "SELECT Status, IssueMovementId FROM inventory.LotSerials WHERE CompanyId=@c AND SerialNo=N'S-2001'",
                new { c = compId });
            Assert.Equal("Out", (string)row.Status);
            Assert.NotNull((int?)row.IssueMovementId);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    /// <summary>فروش سریالی که قبلاً صادر شده (یا اصلاً ثبت نشده) → خطای 51055.</summary>
    [SkippableFact]
    public async Task Sales_of_already_issued_serial_throws()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh) = await SeedAsync(cn);
        try
        {
            var linesJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 1m, GiftQty = 0m, UnitPrice = 1200m,
                      DiscountPercent = 0m, TaxPercent = 0m, DutyPercent = 0m }
            });
            var serialsJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, LotNo = (string?)null, SerialNo = "S-3001", ExpiryDate = (DateTime?)null, Qty = 1m }
            });

            // خرید ۱ واحد بدون سریال (موجودی هست ولی سریال S-3001 ثبت نشده)
            await cn.ExecuteAsync(Script("PurchaseInvoiceInsert.sql"), new
            {
                InvoiceDate = new DateTime(2026, 4, 5),
                SupplierPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                ReferenceNumber = "", PaymentTerms = "Cash", DueDate = (DateTime?)null,
                Description = "خرید بدون سریال", CompanyId = compId, FiscalYearId = (int?)null,
                CreatedBy = "diag", LinesJson = linesJson, SerialsJson = (string?)null
            });

            try
            {
                await cn.ExecuteAsync(Script("SalesInvoiceInsert.sql"), new
                {
                    InvoiceDate = new DateTime(2026, 4, 6),
                    CustomerPartyId = (int?)null, WarehouseId = wh, SubWarehouseId = (int?)null,
                    ReferenceNumber = (string?)null, PaymentTerms = "Cash", DueDate = (DateTime?)null,
                    SaleType = "Retail", Description = "فروش سریالِ ثبت‌نشده", CompanyId = compId,
                    FiscalYearId = (int?)null, CreatedBy = "diag",
                    LinesJson = linesJson, SerialsJson = serialsJson
                });
                Assert.Fail("فروش سریالِ ناموجود باید خطا دهد.");
            }
            catch (SqlException ex) { Assert.Equal(51055, ex.Number); }
        }
        finally { await CleanupAsync(cn, compId); }
    }
}
