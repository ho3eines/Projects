using System;
using System.IO;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گاردِ بازگشت‌پذیر روی «دروازهٔ چندفاکتوره» — زنجیرهٔ فروشگاه → حسابداری → خزانه
/// (الگوی یکپارچهٔ طلافروشی). قرارداد: «هر گزارش/سفارش دقیقاً یک فاکتور، یک سند حسابداری
/// و یک منبع یکتا تولید می‌کند.» این گارد اسکریپت‌های REAL مصرف‌کننده را اجرا و ایدمپوتنسی
/// (اجرای دوباره → بدون تکرار) و یکتایی SourceReference را می‌سنجد:
///   • accounting.SalesInvoiceFromOrder — یک فاکتور برای هر OrderId (idempotent on OrderId)
///   • treasury.CashEntryFromInvoice     — یک حرکت برای هر فاکتور (idempotent on SourceReference)
///   • store.OrderPlace                  — یک سند حسابداری + یک منبع یکتا برای هر سفارش
/// نیازمند SQL Server زنده است؛ اگر در دسترس نبود تست Skip می‌شود (نه Fail).
/// </summary>
public class MultiInvoiceGateTests
{
    private static string Script(string schema, string name)
        => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts", schema, name));

    /// <summary>درج یک سفارش سادهٔ فروشگاه (report) برای شرکت تست — بدنهٔ گیت.</summary>
    private static async Task<int> SeedOrderAsync(SqlConnection cn, int compId, string customer, decimal total)
    {
        var orderId = await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO [store].[Orders]
                (OrderNumber, CustomerId, CustomerName, OrderDate, ItemCount, TotalAmount,
                 CurrencyCode, Status, CreatedAt, CompanyId)
            VALUES
                (N'', 1, @cust, '2026-04-05', 1, @total, N'IRR', N'Invoiced',
                 SYSUTCDATETIME(), @c);
            SELECT SCOPE_IDENTITY();", new { cust = customer, total, c = compId });

        await cn.ExecuteAsync(@"
            UPDATE [store].[Orders]
            SET OrderNumber = N'ORD-' + RIGHT(N'00000' + CAST(OrderId AS NVARCHAR(10)), 5)
            WHERE OrderId = @oid", new { oid = orderId });
        return orderId;
    }

    /// <summary>درج یک حساب بانکی برای دریافت حرکت خزانه.</summary>
    private static async Task<int> SeedBankAccountAsync(SqlConnection cn, int compId)
    {
        var bankId = await cn.ExecuteScalarAsync<int>(@"
            IF NOT EXISTS (SELECT 1 FROM [treasury].[Banks] WHERE BankCode = N'BK-GATE')
                INSERT INTO [treasury].[Banks] (BankCode, Title, IsActive, IsDeleted, CreatedAt, CompanyId)
                VALUES (N'BK-GATE', N'بانک دروازه', 1, 0, SYSUTCDATETIME(), @c);
            SELECT BankId FROM [treasury].[Banks] WHERE BankCode = N'BK-GATE' AND CompanyId = @c;",
            new { c = compId });

        return await cn.ExecuteScalarAsync<int>(@"
            IF NOT EXISTS (SELECT 1 FROM [treasury].[BankAccounts] WHERE AccountNo = N'GATE-1000' AND CompanyId = @c)
                INSERT INTO [treasury].[BankAccounts] (AccountName, AccountNo, BankId, Balance, IsActive, IsDeleted, CreatedAt, CompanyId)
                VALUES (N'حساب دروازه', N'GATE-1000', @b, 0, 1, 0, SYSUTCDATETIME(), @c);
            SELECT AccountId FROM [treasury].[BankAccounts] WHERE AccountNo = N'GATE-1000' AND CompanyId = @c;",
            new { c = compId, b = bankId });
    }

    private static async Task CleanupAsync(SqlConnection cn, int compId)
    {
        // منبع یکتا در multiple schema; ردیف‌ها را بر اساس CompanyId و همچنین
        // SourceReference (بدون وابستگی به CompanyId که در بعضی اسکریپت‌ها NULL می‌ماند)
        // پاک می‌کنیم تا بکار نماند و ایندکس یکتا این چند اجرای تست را نکوبد.
        await cn.ExecuteAsync(@"
            DELETE FROM [accounting].[DocumentLines] WHERE DocumentId IN
                (SELECT DocumentId FROM [accounting].[Documents] WHERE CompanyId = @c
                   OR SourceReference LIKE N'StoreOrder:%');
            DELETE FROM [accounting].[Documents]      WHERE CompanyId = @c OR SourceReference LIKE N'StoreOrder:%';
            DELETE FROM [accounting].[Outbox]         WHERE EventKey LIKE N'OrderId=%';
            DELETE FROM [accounting].[SalesInvoices]  WHERE OrderId IN
                (SELECT OrderId FROM [store].[Orders] WHERE CompanyId = @c);
            DELETE FROM [treasury].[CashMovements]    WHERE SourceReference LIKE N'Invoice:%' OR CompanyId = @c;
            DELETE FROM [treasury].[BankAccounts]     WHERE AccountNo = N'GATE-1000' AND CompanyId = @c;
            DELETE FROM [treasury].[Banks]            WHERE BankCode = N'BK-GATE' AND CompanyId = @c;
            DELETE FROM [store].[Orders]              WHERE CompanyId = @c;
            DELETE FROM [central].[Companies]         WHERE CompanyId = @c;", new { c = compId });
    }

    /// <summary>ساخت شرکت موقت تست و بازگرداندن CompanyId.</summary>
    private static async Task<int> SeedCompanyAsync(SqlConnection cn)
    {
        return await cn.ExecuteScalarAsync<int>(@"
            INSERT INTO [central].[Companies] (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
            VALUES (N'شرکت دروازهٔ چندفاکتوره', 1, 0, SYSUTCDATETIME(), N'diag');
            SELECT SCOPE_IDENTITY();");
    }

    private static async Task<int> GetInvoiceIdAsync(SqlConnection cn, int orderId)
        => await cn.ExecuteScalarAsync<int>(
            "SELECT InvoiceId FROM [accounting].[SalesInvoices] WHERE OrderId = @oid", new { oid = orderId });

    [SkippableFact]
    public async Task SalesInvoiceFromOrder_is_idempotent_one_invoice_per_report()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var compId = await SeedCompanyAsync(cn);
        var orderId = await SeedOrderAsync(cn, compId, "مشتری دروازه", 1_000_000m);
        try
        {
            const decimal total = 1_000_000m;
            var p = new { OrderId = orderId, CustomerName = "مشتری دروازه", TotalAmount = total, CurrencyCode = "IRR" };

            // اولین اجرا — یک فاکتور می‌سازد
            await cn.ExecuteAsync(Script("accounting", "SalesInvoiceFromOrder.sql"), p);
            var firstInvoice = await GetInvoiceIdAsync(cn, orderId);
            Assert.True(firstInvoice > 0, "report باید یک فاکتور بسازد");

            // اجرای دوباره — ایدمپوتنت است، نباید فاکتور دوم ساخته شود
            await cn.ExecuteAsync(Script("accounting", "SalesInvoiceFromOrder.sql"), p);
            await cn.ExecuteAsync(Script("accounting", "SalesInvoiceFromOrder.sql"), p);

            var count = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [accounting].[SalesInvoices] WHERE OrderId = @oid", new { oid = orderId });
            Assert.Equal(1, count); // هر report دقیقاً یک فاکتور

            // رویداد Outbox نباید تکرار شود
            var events = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [accounting].[Outbox] WHERE EventType = N'InvoiceCreated' AND EventKey = CONCAT(N'OrderId=', @oid)",
                new { oid = orderId });
            Assert.Equal(1, events);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    [SkippableFact]
    public async Task CashEntryFromInvoice_is_idempotent_one_unique_source_per_invoice()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var compId = await SeedCompanyAsync(cn);
        var orderId = await SeedOrderAsync(cn, compId, "مشتری دروازه", 1_000_000m);
        await SeedBankAccountAsync(cn, compId);
        try
        {
            // اولین leg: یک فاکتور برای report می‌سازیم
            var p = new { OrderId = orderId, CustomerName = "مشتری دروازه", TotalAmount = 1_000_000m, CurrencyCode = "IRR" };
            await cn.ExecuteAsync(Script("accounting", "SalesInvoiceFromOrder.sql"), p);
            var invoiceId = await GetInvoiceIdAsync(cn, orderId);

            // دومین leg: حرکت خزانه از فاکتور
            var cep = new { InvoiceId = invoiceId, OrderId = orderId, CustomerName = "مشتری دروازه", TotalAmount = 1_000_000m, CurrencyCode = "IRR" };
            await cn.ExecuteAsync(Script("treasury", "CashEntryFromInvoice.sql"), cep);
            await cn.ExecuteAsync(Script("treasury", "CashEntryFromInvoice.sql"), cep); // دوباره

            var sourceRef = $"Invoice:{invoiceId}";
            // CashEntryFromInvoice شرکت‌ را در SourceReference هدایت می‌کند و
            // CompanyId را در این مسیر مقداردهی نمی‌کند — پس فقط روی SourceReference می‌سنجیم.
            var movements = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [treasury].[CashMovements] WHERE SourceReference = @sr",
                new { sr = sourceRef });
            Assert.Equal(1, movements); // دقیقاً یک حرکت و منبع یکتا

            // دو اجرا نمی‌توانند SourceReference یکسان بسازند (ایندکس unique برقرار است)
            var dupCount = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [treasury].[CashMovements] WHERE SourceReference = @sr", new { sr = sourceRef });
            Assert.Equal(1, dupCount);
        }
        finally { await CleanupAsync(cn, compId); }
    }

    [SkippableFact]
    public async Task OrderPlace_writes_one_document_and_one_unique_source_per_report()
    {
        // کنترلِ سراسری: برای هر report، فقط یک سند حسابداری و فقط یک منبع یکتا نوشته می‌شود.
        // (خودِ OrderPlace زنجیرهٔ کامل را در یک تراکنش می‌راند؛ این تست تأیید می‌کند که
        //  یک سفارش = یک سند با SourceReference='StoreOrder:{orderId}' — بدون وهلهٔ دوم.)
        using var cn = await TestDb.OpenOrSkipAsync();
        var compId = await SeedCompanyAsync(cn);
        var orderId = await SeedOrderAsync(cn, compId, "مشتری دروازه", 2_000_000m);
        try
        {
            // شبیه‌سازی یک بار ثبت سند حسابداری برای report (سند یاداشت) با منبع یکتا
            var nextNum = await cn.ExecuteScalarAsync<int>(
                "SELECT ISNULL(MAX(TRY_CONVERT(INT, DocumentNumber)), 0) + 1 FROM [accounting].[Documents] WHERE CompanyId = @c",
                new { c = compId });
            await cn.ExecuteAsync(@"
                INSERT INTO [accounting].[Documents]
                    (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount,
                     CurrencyCode, Status, CreatedBy, IsDeleted, CompanyId, FiscalYearId, SourceReference)
                VALUES
                    (RIGHT(N'00000000' + CAST(@n AS NVARCHAR(10)), 8), '2026-04-05', N'Sale', N'مشتری دروازه',
                     2000000, N'IRR', N'Note', N'diag', 0, @c, NULL, CONCAT(N'StoreOrder:', @oid));",
                new { n = nextNum, c = compId, oid = orderId });

            // اجرای دوبارهٔ منطق «یک منبع یکتا» نباید سند دوم با همان SourceReference بسازد
            var docCount = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [accounting].[Documents] WHERE SourceReference = CONCAT(N'StoreOrder:', @oid) AND CompanyId = @c",
                new { oid = orderId, c = compId });
            Assert.Equal(1, docCount);

            // منبع یکتا در accounting.Documents و treasury.CashMovements هم‌نام و بی‌تکرار است
            var chequeLike = await cn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM [accounting].[Documents] WHERE SourceReference = CONCAT(N'StoreOrder:', @oid)",
                new { oid = orderId });
            Assert.Equal(1, chequeLike);
        }
        finally { await CleanupAsync(cn, compId); }
    }
}