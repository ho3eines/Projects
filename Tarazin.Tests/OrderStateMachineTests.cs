using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گارد State Machine سفارش: <c>store/OrderStatusChange.sql</c> باید انتقال‌های
/// غیرمجاز را در SQL رد کند و انتقال‌های مجاز را با تاریخچه ثبت کند.
///
/// قرارداد (موج ۱ — Multi-Store):
///   * جدول <c>store.OrderStatusTransitions</c> تنها منبع حقیقت انتقال‌های مجاز است؛
///   * انتقال غیرمجاز → THROW 51320 («انتقال وضعیت … مجاز نیست») و هیچ تغییری در سفارش؛
///   * انتقال مجاز → UPDATE وضعیت + ردیف تاریخچه در OrderStatusHistory؛
///   * Cancelled/Rejected → رزروهای فعال انبار آزاد می‌شوند (Saga compensation).
///
/// برای معناداربودن روی هر دیتابیسی (حتی تازه/خالی): خود تست با SQL خالص
/// (شرکت + سفارشِ ایزوله) دادهٔ خودش را می‌سازد و همه‌چیز داخل یک تراکنش است که
/// با پایان تست rollback می‌شود — هیچ داده‌ای در DB باقی نمی‌ماند.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود.
/// </summary>
public class OrderStateMachineTests
{
    private const string ScriptsDir = "../../../../Tarazin.Data/Scripts/store";

    private static string Script(string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptsDir, name));

    /// <summary>
    /// ساخت سفارشِ ایزوله با SQL خالص (بدون OrderPlace) — شرکت خودش + مشتری خودش.
    /// برمی‌گرداند: OrderId، وضعیت اولیه و CompanyId.
    /// </summary>
    private static async Task<(int OrderId, string Status, int CompanyId)> SeedOrderAsync(
        SqlConnection cn, SqlTransaction tx, string status = "Invoiced")
    {
        var companyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست State Machine سفارش', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", transaction: tx);

        var customerId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Customers (CustomerCode, FullName, IsActive, IsDeleted, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'CST-SM', N'مشتری تست SM', 1, 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();",
            new { c = companyId }, transaction: tx);

        var orderId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Orders (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount,
                                      TotalAmount, GrossTotal, DiscountTotal, CurrencyCode, Status,
                                      PaymentStatus, BalanceRial, CreatedAt, CreatedBy, CompanyId)
            VALUES (N'ORD-SM', @cu, N'مشتری تست SM', CAST(SYSDATETIME() AS DATE), 1,
                    1000, 1000, 0, N'IRR', @st,
                    N'Paid', 0, SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();",
            new { cu = customerId, st = status, c = companyId }, transaction: tx);

        await cn.ExecuteAsync(@"
            INSERT INTO store.OrderStatusHistory (OrderId, FromStatus, ToStatus, Reason, ChangedBy)
            VALUES (@o, NULL, @st, N'Seed', N'diag');",
            new { o = orderId, st = status }, transaction: tx);

        return (orderId, status, companyId);
    }

    /// <summary>اجرای OrderStatusChange.sql با پارامترها؛ خطای 51320 را به بیرون پرتاب می‌کند.</summary>
    private static Task ChangeStatusAsync(SqlConnection cn, SqlTransaction tx,
        int orderId, string newStatus, string? expectedStatus, string reason = "تست")
        => cn.ExecuteAsync(Script("OrderStatusChange.sql"), new
        {
            OrderId = orderId,
            NewStatus = newStatus,
            ExpectedStatus = expectedStatus,
            Reason = reason,
            ChangedBy = "diag"
        }, transaction: tx);

    private static async Task<(string Status, int HistoryCount)> ReadStateAsync(
        SqlConnection cn, SqlTransaction tx, int orderId)
    {
        var status = await cn.ExecuteScalarAsync<string>(
            "SELECT Status FROM store.Orders WHERE OrderId = @o;", new { o = orderId }, transaction: tx);
        var history = await cn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM store.OrderStatusHistory WHERE OrderId = @o;", new { o = orderId }, transaction: tx);
        return (status ?? "", history);
    }

    // ── ۱) انتقال غیرمجاز: باید 51320 بدهد و هیچ تغییری نکند ───────────────
    [SkippableFact]
    public async Task Illegal_transition_is_rejected_with_51320_and_no_change()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();

        // Invoiced → Placed: برگشت به عقب — در جدول انتقال‌ها وجود ندارد
        var (orderId, status, _) = await SeedOrderAsync(cn, tx, "Invoiced");
        Assert.Equal("Invoiced", status);

        var ex = await Assert.ThrowsAsync<SqlException>(
            () => ChangeStatusAsync(cn, tx, orderId, "Placed", expectedStatus: null));
        Assert.Equal(51320, ex.Number);

        // سفارش دست‌نخورده: همان وضعیت قبلی، بدون ردیف تاریخچهٔ جدید
        var (after, history) = await ReadStateAsync(cn, tx, orderId);
        Assert.Equal("Invoiced", after);
        Assert.Equal(1, history); // فقط ردیف Seed
    }

    // ── ۲) انتقال غیرمجاز دوم: Completed → Cancelled مجاز نیست ─────────────
    [SkippableFact]
    public async Task Completed_to_Cancelled_is_rejected()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();

        var (orderId, status, _) = await SeedOrderAsync(cn, tx, "Completed");
        Assert.Equal("Completed", status);

        var ex = await Assert.ThrowsAsync<SqlException>(
            () => ChangeStatusAsync(cn, tx, orderId, "Cancelled", expectedStatus: null));
        Assert.Equal(51320, ex.Number);

        var (after, _) = await ReadStateAsync(cn, tx, orderId);
        Assert.Equal("Completed", after);
    }

    // ── ۳) انتقال مجاز: Invoiced → Completed باید کار کند و تاریخچه ثبت شود ─
    [SkippableFact]
    public async Task Legal_transition_updates_status_and_writes_history()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();

        var (orderId, status, _) = await SeedOrderAsync(cn, tx, "Invoiced");

        await ChangeStatusAsync(cn, tx, orderId, "Completed", expectedStatus: "Invoiced",
            reason: "تکمیل تست");

        var (after, history) = await ReadStateAsync(cn, tx, orderId);
        Assert.Equal("Completed", after);
        Assert.Equal(2, history); // Seed + انتقال جدید

        var lastReason = await cn.ExecuteScalarAsync<string>(
            "SELECT TOP 1 Reason FROM store.OrderStatusHistory WHERE OrderId = @o ORDER BY HistoryId DESC;",
            new { o = orderId }, transaction: tx);
        Assert.Equal("تکمیل تست", lastReason);
    }

    // ── ۴) کنترل هم‌زمانی: ExpectedStatus قدیمی → 51321 و هیچ تغییری ───────
    [SkippableFact]
    public async Task Stale_expected_status_is_rejected_with_51321()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();

        var (orderId, _, _) = await SeedOrderAsync(cn, tx, "Invoiced");

        var ex = await Assert.ThrowsAsync<SqlException>(
            () => ChangeStatusAsync(cn, tx, orderId, "Completed", expectedStatus: "Placed"));
        Assert.Equal(51321, ex.Number);

        var (after, history) = await ReadStateAsync(cn, tx, orderId);
        Assert.Equal("Invoiced", after);
        Assert.Equal(1, history);
    }

    // ── ۵) سفارش ناموجود → 51031 ────────────────────────────────────────────
    [SkippableFact]
    public async Task Missing_order_is_rejected_with_51031()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        using var tx = cn.BeginTransaction();

        var ex = await Assert.ThrowsAsync<SqlException>(
            () => ChangeStatusAsync(cn, tx, orderId: 999999, newStatus: "Completed", expectedStatus: null));
        Assert.Equal(51031, ex.Number);
    }

    // ── ۶) جدول انتقال‌ها خالی نشود (منبع حقیقت) ───────────────────────────
    [SkippableFact]
    public async Task Transition_table_has_expected_legal_edges()
    {
        using var cn = await TestDb.OpenOrSkipAsync();

        var edges = (await cn.QueryAsync<(string From, string To)>(@"
            SELECT FromStatus, ToStatus FROM store.OrderStatusTransitions;")).ToList();

        // حداقل‌های قرارداد State Machine — اگر کسی جدول را خالی/کم کرد، گارد قرمز می‌شود
        Assert.Contains(edges, e => e.From == "Invoiced" && e.To == "Completed");
        Assert.Contains(edges, e => e.From == "Invoiced" && e.To == "Cancelled");
        Assert.Contains(edges, e => e.From == "Placed" && e.To == "Cancelled");
        Assert.Contains(edges, e => e.From == "Completed" && e.To == "Returned");
        // و برگشت به عقب هرگز مجاز نیست
        Assert.DoesNotContain(edges, e => e.From == "Invoiced" && e.To == "Placed");
        Assert.DoesNotContain(edges, e => e.From == "Completed" && e.To == "Invoiced");
    }
}
