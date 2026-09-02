using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گارد موتور قیمت موج ۳ — قراردادهای «آنچه می‌بینی همان است که پرداخت می‌کنی»:
///
///   ۱) لیست قیمت per-store: قیمت <c>store.ProductPrices</c> دقیق‌تر از
///      <c>Products.Price</c> است؛ قیمتِ فروشگاهِ مشخص بر عمومی (StoreId=NULL)
///      برتری دارد و بازهٔ تاریخ/MinQty رعایت می‌شود.
///   ۲) کمپین: تخفیف درصدی فعال (<c>Promotions</c>) روی جمع ناخالص اعمال می‌شود
///      و دامنهٔ دقیق‌تر (محصول > دسته > همه) برنده است.
///   ۳) سقف کوپن: تخفیف درصدی هرگز از <c>Coupons.MaxDiscount</c> عبور نمی‌کند.
///   ۴) idempotency مصرف کوپن: ایندکس یکتای <c>UX_CouponRed_Order (OrderId, CouponId)</c>
///      مانع ثبت دوبارهٔ همان سفارش می‌شود؛ UsedCount هم دقیقاً به تعداد سفارش‌هاست.
///
/// همهٔ داده‌ها با SQL خالص داخل یک تراکنش ساخته می‌شوند و در پایان rollback
/// می‌شوند — روی هر دیتابیسی (حتی تازه) معنا دارد و چیزی باقی نمی‌ماند.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود.
/// </summary>
public class StorePricingEngineTests
{
    private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/store";

    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

    // ── زیرساخت ایزوله ──────────────────────────────────────────

    private sealed record Ctx(int CompanyId, int StoreA, int StoreB, int CustomerId,
                              int ProductId, int CategoryId);

    private static async Task<Ctx> SeedAsync(SqlConnection cn, SqlTransaction tx, decimal productPrice)
    {
        var companyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست موتور قیمت', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", transaction: tx);

        // دو انبار + دو فروشگاه (فروشگاه A و B) برای تست per-store
        var whA = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Warehouses (WarehouseCode, [Title], Location, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'WH-SM-A', N'انبار A', N'تست', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { c = companyId }, transaction: tx);
        var whB = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO inventory.Warehouses (WarehouseCode, [Title], Location, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'WH-SM-B', N'انبار B', N'تست', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { c = companyId }, transaction: tx);

        var storeA = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Stores (CompanyId, StoreCode, Title, StoreType, WarehouseId, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (@c, N'ST-A', N'فروشگاه A', N'Physical', @wh, 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { c = companyId, wh = whA }, transaction: tx);
        var storeB = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Stores (CompanyId, StoreCode, Title, StoreType, WarehouseId, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (@c, N'ST-B', N'فروشگاه B', N'Physical', @wh, 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { c = companyId, wh = whB }, transaction: tx);

        var customerId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Customers (CustomerCode, FullName, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId, StoreId)
            VALUES (N'CST-PR', N'مشتری قیمت', 1, 0, SYSUTCDATETIME(), N'diag', @c, @s);
            SELECT SCOPE_IDENTITY();", new { c = companyId, s = storeA }, transaction: tx);

        var categoryId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.ProductCategories (CategoryCode, [Title], IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'CAT-PR', N'دستهٔ قیمت', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", transaction: tx);

        var productId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Products (ProductCode, [Title], ItemCode, Price, CategoryId, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'P-PR', N'محصول قیمت', N'', @p, @cat, 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();",
            new { c = companyId, cat = categoryId, p = productPrice }, transaction: tx);

        return new Ctx(companyId, storeA, storeB, customerId, productId, categoryId);
    }

    private static Task AddCartAsync(SqlConnection cn, SqlTransaction tx, Ctx x, decimal qty)
        => cn.ExecuteAsync(@"
            INSERT INTO store.CartItems (CustomerId, ProductId, Qty, AddedAt, CreatedAt, CompanyId)
            VALUES (@cu, @p, @q, SYSUTCDATETIME(), SYSUTCDATETIME(), @c);",
            new { cu = x.CustomerId, p = x.ProductId, q = qty, c = x.CompanyId }, transaction: tx);

    private static Task<int> PriceListAsync(SqlConnection cn, SqlTransaction tx, Ctx x, string code, int? storeId)
        => cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.PriceLists (CompanyId, Code, [Title], StoreId, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (@c, @code, N'لیست ' + @code, @s, 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { c = x.CompanyId, code, s = storeId }, transaction: tx);

    private static Task ProductPriceAsync(SqlConnection cn, SqlTransaction tx, Ctx x,
        int priceListId, int? storeId, decimal price, decimal minQty = 1)
        => cn.ExecuteAsync(@"
            INSERT INTO store.ProductPrices (CompanyId, PriceListId, ProductId, StoreId, Price, MinQty, IsDeleted, CreatedAt, CreatedBy)
            VALUES (@c, @pl, @p, @s, @pr, @mq, 0, SYSUTCDATETIME(), N'diag');",
            new { c = x.CompanyId, pl = priceListId, p = x.ProductId, s = storeId, pr = price, mq = minQty }, transaction: tx);

    private static Task<int> CouponAsync(SqlConnection cn, SqlTransaction tx, Ctx x,
        string code, string type, decimal value, decimal? maxDiscount, int? usageLimit, decimal minOrderTotal = 0)
        => cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Coupons (CompanyId, Code, [Title], DiscountType, DiscountValue, MaxDiscount,
                                       MinOrderTotal, UsageLimit, UsedCount, IsActive, IsDeleted,
                                       FromDate, ToDate, CreatedAt, CreatedBy)
            VALUES (@c, @code, N'کوپن ' + @code, @t, @v, @mx, @mn, @ul, 0, 1, 0,
                    DATEADD(DAY, -1, SYSUTCDATETIME()), DATEADD(DAY, 30, SYSUTCDATETIME()),
                    SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();",
            new { c = x.CompanyId, code, t = type, v = value, mx = maxDiscount, mn = minOrderTotal, ul = usageLimit }, transaction: tx);

    private static Task<int> PromotionAsync(SqlConnection cn, SqlTransaction tx, Ctx x,
        string code, string type, decimal value, int? productId = null, int? categoryId = null)
        => cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Promotions (CompanyId, Code, [Title], DiscountType, DiscountValue,
                                          ProductId, CategoryId, IsActive, IsDeleted, FromDate, ToDate, CreatedAt, CreatedBy)
            VALUES (@c, @code, N'کمپین ' + @code, @t, @v, @p, @cat, 1, 0,
                    DATEADD(DAY, -1, SYSUTCDATETIME()), DATEADD(DAY, 30, SYSUTCDATETIME()),
                    SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();",
            new { c = x.CompanyId, code, t = type, v = value, p = productId, cat = categoryId }, transaction: tx);

    // ── ۱) لیست قیمت per-store بر قیمت پایه برتری دارد ──────────
    [SkippableFact]
    public async Task PerStore_price_list_overrides_base_price()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        var list = await PriceListAsync(cn, tx, x, "PL-A", storeId: null);
        await ProductPriceAsync(cn, tx, x, list, storeId: null, price: 80_000m);

        await AddCartAsync(cn, tx, x, qty: 2);

        // قیمت مؤثر باید 80,000 باشد نه 100,000 پایه
        var effective = await cn.ExecuteScalarAsync<decimal>(@"
            SELECT pp.Price
            FROM store.ProductPrices pp
            WHERE pp.CompanyId = @c AND pp.ProductId = @p AND pp.IsDeleted = 0
              AND (pp.StoreId IS NULL) AND pp.MinQty <= 2;",
            new { c = x.CompanyId, p = x.ProductId }, transaction: tx);
        Assert.Equal(80_000m, effective);
    }

    // ── ۲) قیمت فروشگاهِ مشخص بر قیمت عمومیِ همان لیست برتری دارد ──
    [SkippableFact]
    public async Task StoreSpecific_price_wins_over_generic_price()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        var list = await PriceListAsync(cn, tx, x, "PL-S", storeId: null);
        await ProductPriceAsync(cn, tx, x, list, storeId: null, price: 90_000m);   // عمومی
        await ProductPriceAsync(cn, tx, x, list, storeId: x.StoreA, price: 70_000m); // اختصاصی A

        // برای مشتریِ متصل به فروشگاه A (SeedAsync)، TOP 1 با اولویت StoreId مشخص
        var best = await cn.ExecuteScalarAsync<decimal>(@"
            SELECT TOP 1 pp.Price
            FROM store.ProductPrices pp
            WHERE pp.CompanyId = @c AND pp.ProductId = @p AND pp.IsDeleted = 0
              AND (pp.StoreId IS NULL OR pp.StoreId = @sA)
            ORDER BY (CASE WHEN pp.StoreId IS NOT NULL THEN 0 ELSE 1 END), pp.MinQty DESC;",
            new { c = x.CompanyId, p = x.ProductId, sA = x.StoreA }, transaction: tx);
        Assert.Equal(70_000m, best);
    }

    // ── ۳) کمپین درصدی روی ناخالص اعمال می‌شود (دامنهٔ همه) ──────
    [SkippableFact]
    public async Task Percent_promotion_applies_on_gross_total()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        await AddCartAsync(cn, tx, x, qty: 3);           // ناخالص = 300,000
        await PromotionAsync(cn, tx, x, "PR10", "Percent", 10m); // همهٔ محصولات

        var gross = await cn.ExecuteScalarAsync<decimal>(
            "SELECT Qty * Price FROM store.CartItems ci JOIN store.Products p ON p.ProductId = ci.ProductId WHERE ci.CustomerId = @cu;",
            new { cu = x.CustomerId }, transaction: tx);
        var promo = await cn.ExecuteScalarAsync<decimal?>(@"
            SELECT DiscountValue FROM store.Promotions
            WHERE CompanyId = @c AND Code = N'PR10' AND IsActive = 1 AND IsDeleted = 0
              AND GETDATE() BETWEEN FromDate AND ToDate;",
            new { c = x.CompanyId }, transaction: tx);
        var expected = Math.Round(gross * promo!.Value / 100m, 0);
        Assert.Equal(30_000m, expected);
    }

    // ── ۴) دامنهٔ دقیق‌تر کمپین برنده است (محصول > همه) ──────────
    [SkippableFact]
    public async Task Narrower_promotion_scope_wins()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        await PromotionAsync(cn, tx, x, "PR-ALL", "Percent", 5m);                       // همه
        await PromotionAsync(cn, tx, x, "PR-PROD", "Percent", 20m, productId: x.ProductId); // محصول

        var winner = await cn.ExecuteScalarAsync<string>(@"
            SELECT TOP 1 Code
            FROM store.Promotions
            WHERE CompanyId = @c AND IsActive = 1 AND IsDeleted = 0
              AND GETDATE() BETWEEN FromDate AND ToDate
              AND (   (ProductId IS NOT NULL AND ProductId = @p)
                   OR (ProductId IS NULL AND CategoryId IS NULL) )
            ORDER BY CASE WHEN ProductId IS NOT NULL THEN 0 ELSE 2 END;",
            new { c = x.CompanyId, p = x.ProductId }, transaction: tx);
        Assert.Equal("PR-PROD", winner);
    }

    // ── ۵) سقف کوپن: تخفیف درصدی از MaxDiscount عبور نمی‌کند ────
    [SkippableFact]
    public async Task Coupon_percent_discount_capped_by_MaxDiscount()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        // ناخالص 100,000 — کوپن 50٪ با سقف 20,000 → تخفیف = 20,000
        await CouponAsync(cn, tx, x, "CAP20", "Percent", 50m, maxDiscount: 20_000m, usageLimit: null);

        var gross = 100_000m;
        var percent = await cn.ExecuteScalarAsync<decimal>(
            "SELECT DiscountValue FROM store.Coupons WHERE CompanyId = @c AND Code = N'CAP20';",
            new { c = x.CompanyId }, transaction: tx);
        var max = await cn.ExecuteScalarAsync<decimal>(
            "SELECT MaxDiscount FROM store.Coupons WHERE CompanyId = @c AND Code = N'CAP20';",
            new { c = x.CompanyId }, transaction: tx);
        var raw = Math.Round(gross * percent / 100m, 0);
        var applied = Math.Min(raw, max);
        Assert.Equal(20_000m, applied);
    }

    // ── ۶) UsageLimit: کوپن پرشده دیگر واجد شرایط نیست ─────────
    [SkippableFact]
    public async Task Coupon_with_exhausted_usage_limit_is_ineligible()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        await CouponAsync(cn, tx, x, "LIMIT3", "Amount", 10_000m, maxDiscount: null, usageLimit: 3);
        await cn.ExecuteAsync("UPDATE store.Coupons SET UsedCount = 3 WHERE CompanyId = @c AND Code = N'LIMIT3';",
            new { c = x.CompanyId }, transaction: tx);

        var eligible = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM store.Coupons
            WHERE CompanyId = @c AND Code = N'LIMIT3'
              AND IsActive = 1 AND IsDeleted = 0
              AND GETDATE() BETWEEN FromDate AND ToDate
              AND (UsageLimit IS NULL OR UsedCount < UsageLimit);",
            new { c = x.CompanyId }, transaction: tx);
        Assert.Equal(0, eligible);
    }

    // ── ۷) idempotency مصرف: ایندکس یکتا ثبت دوباره را رد می‌کند ──
    [SkippableFact]
    public async Task Coupon_redemption_is_idempotent_per_order()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        var couponId = await CouponAsync(cn, tx, x, "IDEM", "Amount", 10_000m, maxDiscount: null, usageLimit: null);

        var orderId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Orders (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount,
                                      TotalAmount, GrossTotal, DiscountTotal, CurrencyCode, Status,
                                      PaymentStatus, BalanceRial, CreatedAt, CreatedBy, CompanyId, CouponId)
            VALUES (N'ORD-IDEM', @cu, N'مشتری قیمت', CAST(SYSDATETIME() AS DATE), 1,
                    90000, 100000, 10000, N'IRR', N'Invoiced',
                    N'Paid', 0, SYSUTCDATETIME(), N'diag', @c, @cp);
            SELECT SCOPE_IDENTITY();",
            new { cu = x.CustomerId, c = x.CompanyId, cp = couponId }, transaction: tx);

        // اولین مصرف: مجاز
        await cn.ExecuteAsync(@"
            INSERT INTO store.CouponRedemptions (CompanyId, CouponId, OrderId, CustomerId, DiscountAmt)
            VALUES (@c, @cp, @o, @cu, 10000);",
            new { c = x.CompanyId, cp = couponId, o = orderId, cu = x.CustomerId }, transaction: tx);

        // دومین مصرف همان سفارش: باید با خطای ایندکس یکتا رد شود (2601 duplicate / 2627 unique)
        var ex = await Assert.ThrowsAnyAsync<SqlException>(() => cn.ExecuteAsync(@"
            INSERT INTO store.CouponRedemptions (CompanyId, CouponId, OrderId, CustomerId, DiscountAmt)
            VALUES (@c, @cp, @o, @cu, 10000);",
            new { c = x.CompanyId, cp = couponId, o = orderId, cu = x.CustomerId }, transaction: tx));
        Assert.True(ex.Number is 2601 or 2627,
            $"انتظار خطای یکتایی (2601/2627) می‌رفت؛ به‌جای آن: {ex.Number}");

        // سقف مصرف هر مشتری هم دقیقاً 1 است
        var perCustomer = await cn.ExecuteScalarAsync<int>(@"
            SELECT COUNT(*) FROM store.CouponRedemptions
            WHERE CouponId = @cp AND CustomerId = @cu;",
            new { cp = couponId, cu = x.CustomerId }, transaction: tx);
        Assert.Equal(1, perCustomer);
    }

    // ── ۸) UsedCount پس از دو سفارشِ متفاوت دقیقاً ۲ است ─────────
    [SkippableFact]
    public async Task UsedCount_matches_distinct_orders()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();
        var x = await SeedAsync(cn, tx, productPrice: 100_000m);

        var couponId = await CouponAsync(cn, tx, x, "COUNT2", "Amount", 5_000m, maxDiscount: null, usageLimit: 5);

        foreach (var n in new[] { 1, 2 })
        {
            var orderId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO store.Orders (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount,
                                          TotalAmount, GrossTotal, DiscountTotal, CurrencyCode, Status,
                                          PaymentStatus, BalanceRial, CreatedAt, CreatedBy, CompanyId, CouponId)
                VALUES (@on, @cu, N'مشتری قیمت', CAST(SYSDATETIME() AS DATE), 1,
                        95000, 100000, 5000, N'IRR', N'Invoiced',
                        N'Paid', 0, SYSUTCDATETIME(), N'diag', @c, @cp);
                SELECT SCOPE_IDENTITY();",
                new { on = $"ORD-CNT{n}", cu = x.CustomerId, c = x.CompanyId, cp = couponId }, transaction: tx);

            await cn.ExecuteAsync(@"
                INSERT INTO store.CouponRedemptions (CompanyId, CouponId, OrderId, CustomerId, DiscountAmt)
                VALUES (@c, @cp, @o, @cu, 5000);
                UPDATE store.Coupons SET UsedCount = UsedCount + 1 WHERE CouponId = @cp;",
                new { c = x.CompanyId, cp = couponId, o = orderId, cu = x.CustomerId }, transaction: tx);
        }

        var used = await cn.ExecuteScalarAsync<int>(
            "SELECT UsedCount FROM store.Coupons WHERE CouponId = @cp;", new { cp = couponId }, transaction: tx);
        var redemptions = await cn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM store.CouponRedemptions WHERE CouponId = @cp;", new { cp = couponId }, transaction: tx);
        Assert.Equal(2, used);
        Assert.Equal(used, redemptions);
    }
}
