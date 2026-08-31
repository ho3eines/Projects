using System;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گاردِ SQL خالص روی اسکریپتِ واقعی <c>treasury.SourceDetail</c> — وضوح «منبع یک چک»
/// به سابقهٔ پشتنویس + سند حسابداری لینک‌شده. برای هر پیشوند منبع، دادهٔ واقعی در همان
/// اسکیمای دامنه درج می‌شود (طلافروشی / فروشگاه / خزانه / حقوق) + یک سند حسابداریِ
/// لینک‌شده، سپس اسکریپت با همان <c>@SourceReference</c> صدا زده می‌شود و تأیید می‌شود
/// که <c>DocumentId</c> / <c>DocumentNumber</c> و <c>ModuleId</c> به‌درستی وضوح می‌شوند.
///
/// نکته: این تست فقط اسکریپت SQL را اجرا می‌کند (نه سرویس/UI) پس اگر کسی در
/// SourceDetail.sql یکی از مسیرها را بشکند (مثلاً نام ستون، JOIN یا شرط CompanyId)،
/// این گارد همان مسیر واقعی را با دادهٔ واقعی می‌کوبد و شکست را می‌گیرد.
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود Skip می‌شود (نه Fail).
/// </summary>
public class SourceDetailSqlGuardTests
{
    private static string Script(string name)
        => System.IO.File.ReadAllText(
            System.IO.Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/treasury", name));

    private sealed record Seed(
        int CompanyId, int FiscalYearId, int DocId, string DocNumber,
        int InvoiceId, string InvoiceNumber,
        int OrderId, string OrderNumber,
        int ChequeId, string ChequeNumber,
        int RunId, string Period);

    private static async Task<Seed> SeedAsync(SqlConnection cn)
    {
        // ── شرکت + سال مالی (دامنه‌سازی اسناد) ──
        var compId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت تست SourceDetail', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");

        var fyId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO central.FiscalYears (CompanyId, YearName, StartDate, EndDate, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (@c, N'1405', '2026-03-21', '2027-03-20', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();", new { c = compId });

        // ── سند حسابداریِ مرجع (با DocumentNumber یکتا) ──
        var docNumber = "SD-" + Guid.NewGuid().ToString("N")[..8];
        var docId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO accounting.Documents
                (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount,
                 CurrencyCode, [Status], CreatedAt, CreatedBy, IsDeleted, CompanyId, FiscalYearId)
            VALUES
                (@docNumber, '2026-04-05', N'Journal', N'طرف تست', 1000000,
                 N'IRR', N'Posted', SYSUTCDATETIME(), N'diag', 0, @c, @fy);
            SELECT SCOPE_IDENTITY();", new { docNumber, c = compId, fy = fyId });

        // ── فاکتور طلافروشی (GoldInvoice) — سند از شرحِ ردیفِ سند وضوح می‌شود ──
        var invoiceNumber = "GINV-" + Guid.NewGuid().ToString("N")[..8];
        var invoiceId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO goldshop.SaleInvoices
                (InvoiceNumber, InvoiceDate, CustomerName, ItemCode, WeightGram,
                 Workmanship, Profit, Tax, TotalAmount, [Status], CreatedAt, CreatedBy,
                 CompanyId, CurrencyCode, PaymentStatus)
            VALUES
                (@invNo, '2026-04-05', N'مشتری طلا', N'G-1', 5.000,
                 100000, 50000, 100000, 1500000, N'Issued', SYSUTCDATETIME(), N'diag',
                 @c, N'IRR', N'Paid');
            SELECT SCOPE_IDENTITY();", new { invNo = invoiceNumber, c = compId });

        // ── سفارش فروشگاه (Order) — DocumentId مستقیم روی خودِ سفارش ذخیره می‌شود ──
        var orderNumber = "ORD-" + Guid.NewGuid().ToString("N")[..8];
        var orderId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO store.Orders
                (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount,
                 TotalAmount, CurrencyCode, [Status], CreatedAt,
                 CompanyId, DocumentId)
            VALUES
                (@ordNo, 1000, N'مشتری فروشگاه', '2026-04-05', 2,
                 500000, N'IRR', N'Invoiced', SYSUTCDATETIME(),
                 @c, @doc);
            SELECT SCOPE_IDENTITY();", new { ordNo = orderNumber, c = compId, doc = docId });

        // ── چک خزانه (Cheque) — DocumentId در این مسیر NULL می‌ماند (فقط ModuleId) ──
        var chequeNumber = "CHQ-" + Guid.NewGuid().ToString("N")[..8];
        var chequeId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO treasury.Cheques
                (ChequeNumber, Amount, DueDate, Direction, [Status], CreatedAt, CompanyId)
            VALUES
                (@chq, 2000000, '2026-05-05', N'In', N'Pending', SYSUTCDATETIME(), @c);
            SELECT SCOPE_IDENTITY();", new { chq = chequeNumber, c = compId });

        // ── دورهٔ حقوق (Payroll) — سند از شرحِ ردیفِ سند (شامل دوره) وضوح می‌شود ──
        var period = "SD-" + Guid.NewGuid().ToString("N")[..8];
        var runId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO payroll.PayrollRuns (Period, EmployeeCount, NetTotal, [Status], CreatedAt, CreatedBy, CompanyId)
            VALUES (@per, 1, 5000000, N'Finalized', SYSUTCDATETIME(), N'diag', @c);
            SELECT SCOPE_IDENTITY();", new { per = period, c = compId });

        // ── ردیف‌های سند: شرح هر ردیف شامل شماره/دورهٔ منبع است تا subquery وضوح کند ──
        await cn.ExecuteAsync(@"
            INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            VALUES (@doc, 1, N'2000', N'دریافت', N'فاکتور ' + @invNo, 1500000, 0);
            INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit)
            VALUES (@doc, 1, N'2000', N'حقوق', N'دورهٔ ' + @per, 5000000, 0);",
            new { doc = docId, invNo = invoiceNumber, per = period });

        // برای مسیر Order Description لازم نیست (DocumentId مستقیم) — ولی برای وضوحِ
        // DocumentNumber خوانده می‌شود از خودِ Documents (نه وابسته به شرح).

        return new Seed(compId, fyId, docId, docNumber, invoiceId, invoiceNumber,
            orderId, orderNumber, chequeId, chequeNumber, runId, period);
    }

    private static async Task CleanupAsync(SqlConnection cn, Seed s)
    {
        await cn.ExecuteAsync(@"
            DELETE FROM accounting.DocumentLines WHERE DocumentId=@doc;
            DELETE FROM accounting.Documents      WHERE DocumentId=@doc;
            DELETE FROM goldshop.SaleInvoices     WHERE InvoiceId=@inv;
            DELETE FROM store.Orders              WHERE OrderId=@ord;
            DELETE FROM treasury.Cheques          WHERE ChequeId=@chq;
            DELETE FROM payroll.PayrollRuns       WHERE RunId=@run;
            DELETE FROM central.FiscalYears       WHERE CompanyId=@c;
            DELETE FROM central.Companies         WHERE CompanyId=@c;",
            new { doc = s.DocId, inv = s.InvoiceId, ord = s.OrderId, chq = s.ChequeId, run = s.RunId, c = s.CompanyId });
    }

    private static async Task<dynamic?> ResolveAsync(SqlConnection cn, Seed s, string sourceReference)
        => await cn.QueryFirstOrDefaultAsync<dynamic>(
            Script("SourceDetail.sql"),
            new
            {
                SourceReference = sourceReference,
                CompanyId = s.CompanyId,
                FiscalYearId = s.FiscalYearId
            });

    [SkippableFact]
    public async Task GoldInvoice_and_GoldPurchase_resolve_document_from_line_description()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var s = await SeedAsync(cn);
        try
        {
            foreach (var prefix in new[] { "GoldInvoice", "GoldPurchase" })
            {
                var row = await ResolveAsync(cn, s, $"{prefix}:{s.InvoiceId}");
                Assert.NotNull(row);
                Assert.Equal(prefix, (string)row.SourceType);
                Assert.Equal(s.InvoiceId, (int)row.SourceId);
                Assert.Equal(s.InvoiceNumber, (string)row.Key);
                Assert.Equal(s.DocId, (int)row.DocumentId);
                Assert.Equal(s.DocNumber, (string)row.DocumentNumber);
                Assert.Equal(s.InvoiceId, (int)row.ModuleId);
            }
        }
        finally { await CleanupAsync(cn, s); }
    }

    [SkippableFact]
    public async Task Order_StoreOrder_Invoice_resolve_stored_document_directly()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var s = await SeedAsync(cn);
        try
        {
            foreach (var prefix in new[] { "Order", "StoreOrder", "Invoice" })
            {
                var row = await ResolveAsync(cn, s, $"{prefix}:{s.OrderId}");
                Assert.NotNull(row);
                Assert.Equal(prefix, (string)row.SourceType);
                Assert.Equal(s.OrderId, (int)row.SourceId);
                Assert.Equal(s.OrderNumber, (string)row.Key);
                Assert.Equal(s.DocId, (int)row.DocumentId);          // مستقیم از Orders.DocumentId
                Assert.Equal(s.DocNumber, (string)row.DocumentNumber);
                Assert.Equal(s.OrderId, (int)row.ModuleId);
            }
        }
        finally { await CleanupAsync(cn, s); }
    }

    [SkippableFact]
    public async Task Cheque_prefix_returns_module_id_and_null_document()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var s = await SeedAsync(cn);
        try
        {
            var row = await ResolveAsync(cn, s, $"Cheque:{s.ChequeId}");
            Assert.NotNull(row);
            Assert.Equal("Cheque", (string)row.SourceType);
            Assert.Equal(s.ChequeId, (int)row.SourceId);
            Assert.Equal(s.ChequeNumber, (string)row.Key);
            Assert.False(row.DocumentId is int, "مسیر Cheque نباید DocumentId برنگرداند (وصولِ بعدی سندِ خودش را می‌سازد).");
            Assert.Equal(s.ChequeId, (int)row.ModuleId);
        }
        finally { await CleanupAsync(cn, s); }
    }

    [SkippableFact]
    public async Task Payroll_prefix_resolves_document_from_period_in_description()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var s = await SeedAsync(cn);
        try
        {
            var row = await ResolveAsync(cn, s, $"Payroll:{s.RunId}");
            Assert.NotNull(row);
            Assert.Equal("Payroll", (string)row.SourceType);
            Assert.Equal(s.RunId, (int)row.SourceId);
            Assert.Equal(s.Period, (string)row.Key);
            Assert.Equal(s.DocId, (int)row.DocumentId);           // از شرحِ ردیفِ سند (دوره)
            Assert.Equal(s.DocNumber, (string)row.DocumentNumber);
            Assert.Equal(s.RunId, (int)row.ModuleId);
        }
        finally { await CleanupAsync(cn, s); }
    }

    [SkippableFact]
    public async Task Manual_or_unknown_prefix_returns_raw_row_with_null_document()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var s = await SeedAsync(cn);
        try
        {
            // پیشوند ناشناخته که جزو هیچ‌کدام نیست → ردیفِ «دستی» با DocumentId NULL
            var row = await ResolveAsync(cn, s, $"Swap:{42}");
            Assert.NotNull(row);
            Assert.False(row is null);
            Assert.Equal("Swap", (string)row.SourceType);
            Assert.False(row.DocumentId is int, "پیشوند دستی نباید سند برگرداند.");

            // منبعِ خالی/بی‌دونقطه → ردیفِ دستی با Key خودِ منبع
            var manualRow = await ResolveAsync(cn, s, "راستدستی");
            Assert.NotNull(manualRow);
            Assert.Equal("", (string)manualRow.SourceType);
            Assert.Equal("راستدستی", (string)manualRow.Key);
            Assert.False(manualRow.DocumentId is int);
        }
        finally { await CleanupAsync(cn, s); }
    }
}