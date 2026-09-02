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
/// سناریوی «تعدیل و انبارگردانی کامل» — StocktakeRun باید مغایرت را علاوه بر
/// حرکت انبار، به‌صورت سند حسابداری (StocktakeAdjustment) ثبت کند تا تراز
/// انبار/حسابداری جابه‌جا نشود. الگو: InventoryPhase5Tests.
/// </summary>
public class InventoryAdjustmentTests
{
    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

    private static async Task<(int CompanyId, int ItemId, int WarehouseId, int FiscalYearId)> SeedAsync(SqlConnection cn)
    {
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست انبارگردانی', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var itemId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CompanyId)
            VALUES (N'ADJ-' + LEFT(CAST(NEWID() AS NVARCHAR(36)), 6), N'کالای تست تعدیل', 0, 700, 0, SYSUTCDATETIME(), @c);
            SELECT SCOPE_IDENTITY();", new { c = compId });

        var whCode = "W" + Guid.NewGuid().ToString("N")[..4];
        var wh = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CompanyId)
            VALUES (@code, N'انبار تست تعدیل', 1, 0, @c);
            SELECT SCOPE_IDENTITY();", new { code = whCode, c = compId });

        // تنظیمات انبار فعال + حساب انبار و حساب مقابل تعدیل (بدون FK — مقدار ساده)
        await cn.ExecuteAsync(@"
            INSERT INTO inventory.InventorySettings
                (CompanyId, CostingMethod, IsEnabled, InventoryAccountId, InventoryAccountCode, InventoryAccountTitle,
                 ReceiptContraAccountId, ReceiptContraAccountCode, ReceiptContraAccountTitle,
                 AdjustmentAccountId, AdjustmentAccountCode, AdjustmentAccountTitle, UpdatedAt)
            VALUES
                (@c, N'WeightedAverage', 1, 1001, N'1001', N'موجودی کالا', 3001, N'3001', N'تأمین‌کننده',
                 2001, N'2001', N'هزینه تعدیل', SYSUTCDATETIME());",
            new { c = compId });

        var fyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, IsDeleted, CreatedAt, CreatedBy, Status)
            VALUES (@c, N'سال ۱۴۰۵', N'2026-03-21', N'2027-03-20', 1, 0, SYSUTCDATETIME(), N'diag', N'Open');
            SELECT SCOPE_IDENTITY();", new { c = compId });

        return (compId, itemId, wh, fyId);
    }

    private static async Task CleanupAsync(SqlConnection cn, int compId)
    {
        await cn.ExecuteAsync(@"
            DELETE FROM accounting.DocumentLines WHERE DocumentId IN (SELECT DocumentId FROM accounting.Documents WHERE CompanyId=@c);
            DELETE FROM accounting.Documents WHERE CompanyId=@c;
            DELETE FROM inventory.InvoiceLines WHERE InvoiceId IN (SELECT InvoiceId FROM inventory.Invoices WHERE CompanyId=@c);
            DELETE FROM inventory.Invoices WHERE CompanyId=@c;
            DELETE FROM inventory.StockLayers WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Movements WHERE ItemId IN (SELECT ItemId FROM inventory.Items WHERE CompanyId=@c);
            DELETE FROM inventory.Outbox WHERE EventKey LIKE N'MovementId=%';
            DELETE FROM inventory.Items WHERE CompanyId=@c;
            DELETE FROM inventory.SubWarehouses WHERE WarehouseId IN (SELECT WarehouseId FROM inventory.Warehouses WHERE CompanyId=@c);
            DELETE FROM inventory.Warehouses WHERE CompanyId=@c;
            DELETE FROM inventory.InventorySettings WHERE CompanyId=@c;
            DELETE FROM central.FiscalYears WHERE CompanyId=@c;
            DELETE FROM central.Companies WHERE CompanyId=@c;", new { c = compId });
    }

    /// <summary>مغایرت مثبت (شمارش بیشتر از موجودی) → سند StocktakeAdjustment با بدهکار موجودی/بستانکار تعدیل.</summary>
    [SkippableFact]
    public async Task Positive_variance_posts_adjustment_document()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh, fyId) = await SeedAsync(cn);
        try
        {
            // شمارش ۵ عدد در حالی که موجودی ۰ است → مغایرت +۵ × قیمت ۷۰۰ = ۳٬۵۰۰
            await cn.ExecuteAsync(Script("StocktakeRun.sql"), new
            {
                ItemId = itemId,
                WarehouseId = wh,
                SubWarehouseId = (int?)null,
                CountedQty = 5m,
                FiscalYearId = fyId,
                CompanyId = compId,
                CreatedBy = "diag"
            });

            var stock = await cn.ExecuteScalarAsync<decimal>(
                "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
            Assert.Equal(5m, stock);

            var doc = await cn.QuerySingleAsync<dynamic>(@"
                SELECT d.TotalAmount, l1.AccountId AS DebitAcct, l1.Debit, l2.AccountId AS CreditAcct, l2.Credit
                FROM accounting.Documents d
                JOIN accounting.DocumentLines l1 ON l1.DocumentId = d.DocumentId AND l1.Debit > 0
                JOIN accounting.DocumentLines l2 ON l2.DocumentId = d.DocumentId AND l2.Credit > 0
                WHERE d.CompanyId=@c AND d.DocumentType=N'StocktakeAdjustment'",
                new { c = compId });

            Assert.NotNull(doc);
            Assert.Equal(3500m, (decimal)doc.TotalAmount);
            Assert.Equal(1001, (int)doc.DebitAcct);    // بدهکار: موجودی کالا
            Assert.Equal(3500m, (decimal)doc.Debit);
            Assert.Equal(2001, (int)doc.CreditAcct);   // بستانکار: هزینه تعدیل
            Assert.Equal(3500m, (decimal)doc.Credit);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    /// <summary>مغایرت منفی (شمارش کمتر از موجودی) → سند معکوس: بدهکار تعدیل / بستانکار موجودی.</summary>
    [SkippableFact]
    public async Task Negative_variance_posts_reversed_document()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var (compId, itemId, wh, fyId) = await SeedAsync(cn);
        try
        {
            // خرید ۱۰ عدد با قیمت ۵۰۰ (سند خرید هم ساخته می‌شود ولی با نوع PurchaseInvoice)
            var linesJson = JsonSerializer.Serialize(new[]
            {
                new { ItemId = itemId, Qty = 10m, GiftQty = 0m, UnitPrice = 500m,
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
                Description = "خرید پایه",
                CompanyId = compId,
                FiscalYearId = fyId,
                CreatedBy = "diag",
                LinesJson = linesJson,
                SerialsJson = (string?)null
            });

            // شمارش ۴ → مغایرت -۶ × بهای تمام‌شده ۵۰۰ = ۳٬۰۰۰
            await cn.ExecuteAsync(Script("StocktakeRun.sql"), new
            {
                ItemId = itemId,
                WarehouseId = wh,
                SubWarehouseId = (int?)null,
                CountedQty = 4m,
                FiscalYearId = fyId,
                CompanyId = compId,
                CreatedBy = "diag"
            });

            var stock = await cn.ExecuteScalarAsync<decimal>(
                "SELECT StockQty FROM inventory.Items WHERE ItemId=@i", new { i = itemId });
            Assert.Equal(4m, stock);

            var doc = await cn.QuerySingleAsync<dynamic>(@"
                SELECT d.TotalAmount, l1.AccountId AS DebitAcct, l1.Debit, l2.AccountId AS CreditAcct, l2.Credit
                FROM accounting.Documents d
                JOIN accounting.DocumentLines l1 ON l1.DocumentId = d.DocumentId AND l1.Debit > 0
                JOIN accounting.DocumentLines l2 ON l2.DocumentId = d.DocumentId AND l2.Credit > 0
                WHERE d.CompanyId=@c AND d.DocumentType=N'StocktakeAdjustment'",
                new { c = compId });

            Assert.NotNull(doc);
            Assert.Equal(3000m, (decimal)doc.TotalAmount);
            Assert.Equal(2001, (int)doc.DebitAcct);    // بدهکار: هزینه تعدیل
            Assert.Equal(3000m, (decimal)doc.Debit);
            Assert.Equal(1001, (int)doc.CreditAcct);   // بستانکار: موجودی کالا
            Assert.Equal(3000m, (decimal)doc.Credit);
        }
        finally { await CleanupAsync(cn, compId); }
    }
}
