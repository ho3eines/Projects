using System;
using System.IO;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// E2E یکپارچگی فروشگاه (OrderPlace): ثبت سفارش POS و اثبات زنجیرهٔ یکپارچه با
/// انبار، دفتر مشتری، خزانه و حسابداری:
///   ۱) انبار: مصرف FIFO (StockLayers.QtyRemaining)، رکورد Movements (Issue) و کاهش Items.StockQty
///   ۲) دفتر مشتری: OrderLedger (بدهکار کل / بستانکار تسویه)
///   ۳) خزانه: CashMovements + افزایش ماندهٔ CashBoxes
///   ۴) حسابداری: سند دوبل (Documents + DocumentLines تراز) + DocumentId روی سفارش
/// الگو: StorePricingEngineTests (Seed → Act → Assert → Rollback با Transaction؛
/// COMMIT داخلی OrderPlace به‌عنوان تراکنش تودرتو فقط شمارنده را کم می‌کند و
/// Rollback بیرونی همه‌چیز را برمی‌گرداند). نیازمند SQL Server زنده.
/// </summary>
public class StoreOrderE2ETests
{
    private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/store";

    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

    private sealed record Ctx(
        int CompanyId, int FiscalYearId, int WarehouseId, int StoreId,
        int CustomerId, int ProductId, int ItemId, int LayerId,
        int CashBoxId, int BankAccountId, int PartyId, string ItemCode,
        string SalesCode, string CashCode, string PartyCode);

    // ── زیرساخت ایزوله ──────────────────────────────────────────
    private static async Task<Ctx> SeedAsync(SqlConnection cn, SqlTransaction tx)
    {
        var u = Guid.NewGuid().ToString("N")[..8];

        var companyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت E2E فروشگاه ' + @u, 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { u }, tx);

        var fyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, IsDeleted, CreatedAt, CreatedBy, Status)
            VALUES (@c, N'سال ۱۴۰۵', N'2026-03-21', N'2027-03-20', 1, 0, SYSUTCDATETIME(), N'diag', N'Open');
            SELECT SCOPE_IDENTITY();", new { c = companyId }, tx);

        var whId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Warehouses (WarehouseCode, [Title], Location, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'WH-' + @u, N'انبار E2E', N'تست', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { u, c = companyId }, tx);

        var storeId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Stores (CompanyId, StoreCode, Title, StoreType, WarehouseId, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (@c, N'ST-' + @u, N'فروشگاه E2E', N'Physical', @wh, 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { u, c = companyId, wh = whId }, tx);

        var catId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.ProductCategories (CategoryCode, [Title], IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'CAT-' + @u, N'دستهٔ E2E', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { u, c = companyId }, tx);

        var itemCode = "ITM-" + u;
        var itemId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Items (ItemCode, ItemTitle, StockQty, UnitPrice, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (@code, N'کالای E2E', 100, 0, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { code = itemCode, c = companyId }, tx);

        // لایهٔ موجودی باید به حرکت رسید (Receipt) خودش ارجاع دهد (ReceiptMovementId NOT NULL)
        var receiptMvId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Movements
                (MovementNumber, MovementType, ItemId, WarehouseId, SubWarehouseId, Qty, UnitPrice, CostPrice,
                 MovementDate, Description, Status, CreatedBy, CompanyId)
            VALUES (N'', N'Receipt', @i, @wh, NULL, 100, 5000, 5000, SYSUTCDATETIME(), N'رسید اولیه E2E', N'Posted', N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { i = itemId, wh = whId, c = companyId }, tx);

        var layerId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.StockLayers (ItemId, WarehouseId, SubWarehouseId, QtyRemaining, UnitCost, ReceivedDate, ReceiptMovementId, CompanyId)
            VALUES (@i, @wh, NULL, 100, 5000, SYSUTCDATETIME(), @rm, @c);
            SELECT SCOPE_IDENTITY();", new { i = itemId, wh = whId, rm = receiptMvId, c = companyId }, tx);

        var partyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Parties (PartyCode, PartyType, FullName, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'PTY-' + @u, N'Customer', N'مشتری E2E', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { u, c = companyId }, tx);

        var partyCode = "1501-" + u;
        await cn.ExecuteAsync(@"
            INSERT INTO treasury.PartyLinks (CompanyId, PartyId, PartyType, DetailLinkId, DetailAccountCode, CreatedAt, CreatedBy)
            VALUES (@c, @p, N'Customer', 900001, @code, SYSUTCDATETIME(), N'diag');",
            new { c = companyId, p = partyId, code = partyCode }, tx);

        var customerId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Customers (CustomerCode, FullName, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId, PartyId, StoreId)
            VALUES (N'CST-' + @u, N'مشتری E2E', 1, 0, SYSUTCDATETIME(), N'diag', @c, @p, @s);
            SELECT SCOPE_IDENTITY();", new { u, c = companyId, p = partyId, s = storeId }, tx);

        var cashBoxId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO treasury.CashBoxes (CashBoxCode, [Title], Balance, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'CB-' + @u, N'صندوق E2E', 0, 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { u, c = companyId }, tx);

        var bankAccId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO treasury.BankAccounts (AccountName, AccountNo, BankId, Balance, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'حساب E2E', N'123456', NULL, 0, 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { c = companyId }, tx);

        const string salesCode = "3001", cashCode = "1001";
        await cn.ExecuteAsync(@"
            INSERT INTO store.StoreSettings
                (CompanyId, InventoryWarehouseId,
                 SalesAccountId, SalesAccountCode, SalesAccountTitle,
                 InventoryAccountId, InventoryAccountCode, InventoryAccountTitle,
                 CashAccountId, CashAccountCode, CashAccountTitle,
                 BankChartAccountId, BankChartAccountCode, BankChartAccountTitle,
                 CashBoxId, BankAccountId, IsEnabled, UpdatedBy)
            VALUES (@c, @wh,
                    300101, @salesCode, N'فروش فروشگاه',
                    120001, N'1200', N'موجودی کالا',
                    100101, @cashCode, N'صندوق',
                    100102, N'1002', N'بانک',
                    @cb, @ba, 1, N'diag');",
            new { c = companyId, wh = whId, salesCode, cashCode, cb = cashBoxId, ba = bankAccId }, tx);

        var productId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Products (ProductCode, [Title], ItemCode, Price, CategoryId, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'P-' + @u, N'محصول E2E', @itemCode, 100000, @cat, 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { u, itemCode, cat = catId, c = companyId }, tx);

        await cn.ExecuteAsync(@"
            INSERT INTO store.CartItems (CustomerId, ProductId, Qty, AddedAt, CreatedAt, CompanyId)
            VALUES (@cu, @p, 2, SYSUTCDATETIME(), SYSUTCDATETIME(), @c);",
            new { cu = customerId, p = productId, c = companyId }, tx);

        return new Ctx(companyId, fyId, whId, storeId, customerId, productId, itemId,
            layerId, cashBoxId, bankAccId, partyId, itemCode, salesCode, cashCode, partyCode);
    }

    private static async Task<dynamic> PlaceOrderAsync(SqlConnection cn, SqlTransaction tx, Ctx x, decimal payCash)
    {
        var result = await cn.QueryFirstAsync(Script("OrderPlace.sql"), new
        {
            CustomerId = x.CustomerId,
            OrderDate = DateTime.Today,
            CompanyId = x.CompanyId,
            FiscalYearId = x.FiscalYearId,
            CreatedBy = "diag",
            StoreId = x.StoreId,
            PriceListId = (int?)null,
            CouponCode = (string?)null,
            PayCash = payCash,
            PayBank = 0m,
            ChequeNumber = (string?)null,
            ChequeBankId = (int?)null,
            ChequeAmount = 0m,
            ChequeDueDate = (DateTime?)null
        }, tx);
        return result;
    }

    // ── ۱) پرداخت کامل: زنجیرهٔ کامل یکپارچه ─────────────────────
    [SkippableFact]
    public async Task Full_cash_order_posts_stock_ledger_cash_and_balanced_document()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx);

        const decimal total = 200_000m; // 2 × 100,000
        var r = await PlaceOrderAsync(cn, tx, x, payCash: total);
        var orderId = (int)r.OrderId;
        var docId = (int)r.DocumentId;

        // ۱) سفارش
        var ord = await cn.QuerySingleAsync<(string Status, string PayStatus, decimal Bal, int ItemCount, int DocId)>(@"
            SELECT Status, PaymentStatus, BalanceRial, ItemCount, DocumentId
            FROM store.Orders WHERE OrderId=@o;", new { o = orderId }, tx);
        Assert.Equal("Invoiced", ord.Status);
        Assert.Equal("Paid", ord.PayStatus);
        Assert.Equal(0m, ord.Bal);
        Assert.Equal(1, ord.ItemCount);
        Assert.Equal(docId, ord.DocId);

        // ۲) انبار: لایهٔ FIFO + Movements + StockQty
        var rem = await cn.ExecuteScalarAsync<decimal>(
            "SELECT QtyRemaining FROM inventory.StockLayers WHERE LayerId=@l;", new { l = x.LayerId }, tx);
        Assert.Equal(98m, rem);
        var stock = await cn.ExecuteScalarAsync<decimal>(
            "SELECT StockQty FROM inventory.Items WHERE ItemId=@i;", new { i = x.ItemId }, tx);
        Assert.Equal(98m, stock);
        var mv = await cn.QuerySingleAsync<(string Type, decimal Qty, decimal Cost)>(
            "SELECT MovementType, Qty, CostPrice FROM inventory.Movements WHERE ItemId=@i AND WarehouseId=@w AND MovementType=N'Issue';",
            new { i = x.ItemId, w = x.WarehouseId }, tx);
        Assert.Equal("Issue", mv.Type);
        Assert.Equal(2m, mv.Qty);
        Assert.Equal(5000m, mv.Cost); // FIFO از لایهٔ ۵۰۰۰

        // ۳) دفتر مشتری
        var led = await cn.QuerySingleAsync<(string Type, decimal Dr, decimal Cr)>(
            "SELECT EntryType, DebitRial, CreditRial FROM store.OrderLedger WHERE OrderId=@o;",
            new { o = orderId }, tx);
        Assert.Equal("OrderSale", led.Type);
        Assert.Equal(total, led.Dr);
        Assert.Equal(total, led.Cr);

        // ۴) خزانه: حرکت نقدی + ماندهٔ صندوق
        var cm = await cn.QuerySingleAsync<(string Dir, decimal Amt)>(
            "SELECT Direction, Amount FROM treasury.CashMovements WHERE SourceReference LIKE N'StoreOrder:%' AND CashBoxId=@cb;",
            new { cb = x.CashBoxId }, tx);
        Assert.Equal("In", cm.Dir);
        Assert.Equal(total, cm.Amt);
        var cbBal = await cn.ExecuteScalarAsync<decimal>(
            "SELECT Balance FROM treasury.CashBoxes WHERE CashBoxId=@c;", new { c = x.CashBoxId }, tx);
        Assert.Equal(total, cbBal);

        // ۵) سند حسابداری دوبلِ تراز
        var doc = await cn.QuerySingleAsync<(string Type, string Status, decimal Total)>(
            "SELECT DocumentType, Status, TotalAmount FROM accounting.Documents WHERE DocumentId=@d;",
            new { d = docId }, tx);
        Assert.Equal("Sale", doc.Type);
        Assert.Equal("Note", doc.Status);
        Assert.Equal(total, doc.Total);

        var (sD, sC) = await cn.QuerySingleAsync<(decimal, decimal)>(@"
            SELECT SUM(Debit), SUM(Credit) FROM accounting.DocumentLines WHERE DocumentId=@d;",
            new { d = docId }, tx);
        Assert.Equal(total, sD);
        Assert.Equal(total, sC); // تراز
        var credSales = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM accounting.DocumentLines
            WHERE DocumentId=@d AND AccountCode=@code AND Credit=@total AND Debit=0;",
            new { d = docId, code = x.SalesCode, total }, tx);
        Assert.Equal(1, credSales);
        var debCash = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM accounting.DocumentLines
            WHERE DocumentId=@d AND AccountCode=@code AND Debit=@total AND Credit=0;",
            new { d = docId, code = x.CashCode, total }, tx);
        Assert.Equal(1, debCash);
    }

    // ── ۲) پرداخت جزئی: نسیه در دفتر مشتری و سند ─────────────────
    [SkippableFact]
    public async Task Partial_payment_leaves_customer_balance_and_posts_receivable()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx);

        const decimal total = 200_000m;
        const decimal payCash = 80_000m;
        const decimal remainder = 120_000m;
        var r = await PlaceOrderAsync(cn, tx, x, payCash: payCash);
        var orderId = (int)r.OrderId;
        var docId = (int)r.DocumentId;

        var ord = await cn.QuerySingleAsync<(string PayStatus, decimal Bal)>(
            "SELECT PaymentStatus, BalanceRial FROM store.Orders WHERE OrderId=@o;", new { o = orderId }, tx);
        Assert.Equal("Partial", ord.PayStatus);
        Assert.Equal(remainder, ord.Bal);

        var led = await cn.QuerySingleAsync<(decimal Dr, decimal Cr)>(
            "SELECT DebitRial, CreditRial FROM store.OrderLedger WHERE OrderId=@o;", new { o = orderId }, tx);
        Assert.Equal(total, led.Dr);
        Assert.Equal(payCash, led.Cr);

        // سند: بدهکار نسیه (مشتری) + نقدی در برابر بستانکار فروش — تراز
        var (sD, sC) = await cn.QuerySingleAsync<(decimal, decimal)>(@"
            SELECT SUM(Debit), SUM(Credit) FROM accounting.DocumentLines WHERE DocumentId=@d;",
            new { d = docId }, tx);
        Assert.Equal(total, sD);
        Assert.Equal(total, sC);
        var debParty = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM accounting.DocumentLines
            WHERE DocumentId=@d AND AccountCode=@code AND Debit=@rem;",
            new { d = docId, code = x.PartyCode, rem = remainder }, tx);
        Assert.Equal(1, debParty);
        var debCash = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM accounting.DocumentLines
            WHERE DocumentId=@d AND AccountCode=@code AND Debit=@cash;",
            new { d = docId, code = x.CashCode, cash = payCash }, tx);
        Assert.Equal(1, debCash);

        var cbBal = await cn.ExecuteScalarAsync<decimal>(
            "SELECT Balance FROM treasury.CashBoxes WHERE CashBoxId=@c;", new { c = x.CashBoxId }, tx);
        Assert.Equal(payCash, cbBal);
    }

    // ── ۳) شمارهٔ مشترک: لنگر DocumentId روی خزانه + گزارش DocumentTrace ──
    // پس از ثبت سفارش، کلید مشترک SourceReference ('StoreOrder:{id}') روی سند،
    // حرکت انبار، حرکت نقدی و چک نوشته می‌شود؛ لنگر DocumentId نیز از
    // این تراکنش به ردیف‌های خزانه منتقل می‌شود تا گزارش DocumentTrace
    // زنجیرهٔ فروشگاه→انبار→خزانه→حسابداری را در یک کوئری برگرداند.
    [SkippableFact]
    public async Task Document_trace_links_store_inventory_treasury_accounting()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx);

        const decimal total = 200_000m;
        var r = await PlaceOrderAsync(cn, tx, x, payCash: total);
        var orderId = (int)r.OrderId;
        var docId = (int)r.DocumentId;

        // لنگر حسابداری روی حرکت نقدی خزانه (پیوند مستقیم خزانه ↔ حسابداری)
        var cmDoc = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM treasury.CashMovements
            WHERE SourceReference = CONCAT(N'StoreOrder:', @o) AND DocumentId = @d;",
            new { o = orderId, d = docId }, tx);
        Assert.Equal(1, cmDoc);

        // کلید مشترک روی حرکت انبار
        var mvSrc = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM inventory.Movements
            WHERE SourceReference = CONCAT(N'StoreOrder:', @o) AND MovementType = N'Issue';",
            new { o = orderId }, tx);
        Assert.Equal(1, mvSrc);

        // گزارش ردیابی یک‌پارچه — ورودی فقط DocumentId
        var docNum = await cn.ExecuteScalarAsync<string>(
            "SELECT DocumentNumber FROM accounting.Documents WHERE DocumentId=@d;", new { d = docId }, tx);
        var trace = Script("../accounting/DocumentTrace.sql");
        var legs = (await cn.QueryAsync<(string Leg, string Key, string Detail, decimal Amount, DateTime? Date, string Src, int? DocId, string DocNum)>(
            trace, new { DocumentId = docId, SourceReference = (string?)null }, tx)).ToList();
        Assert.Contains(legs, l => l.Leg == "حسابداری" && l.Key == docNum);
        Assert.Contains(legs, l => l.Leg == "فروشگاه");
        Assert.Contains(legs, l => l.Leg == "خزانه (نقد)" && l.DocId == docId);
        Assert.Contains(legs, l => l.Leg == "حرکت انبار");

        // ورودی فقط کلید مشترک هم همان زنجیره را می‌دهد
        var legs2 = (await cn.QueryAsync<(string Leg, string Key, string Detail, decimal Amount, DateTime? Date, string Src, int? DocId, string DocNum)>(
            trace, new { DocumentId = (int?)null, SourceReference = $"StoreOrder:{orderId}" }, tx)).ToList();
        Assert.Contains(legs2, l => l.Leg == "حسابداری" && l.DocId == docId);
        Assert.Contains(legs2, l => l.Leg == "خزانه (نقد)");
    }
}
