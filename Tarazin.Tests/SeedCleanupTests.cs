using System;
using System.IO;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// تست seed-cleanup.sql (ابزار tools/seed-demo-data.sh --reseed):
    ///   ۱) پاک‌سازی فقط نشانگرهای خودِ sampleها (توضیحات «نمونه»، «GINV-»، چک
    ///      CHQ-SAMPLE، فاکتور XAU-24، صندوق GoldInvoice:) را حذف می‌کند؛
    ///   ۲) دادهٔ سید اصلی (_Seed.sql: حرکت بدون نشانگر، فاکتور XAU-18/GINV-00001،
    ///      چک عادی) را دست نمی‌زند؛
    ///   ۳) لایه‌های FIFO sample حذف و Items.StockQty از لایه‌های باقی‌مانده
    ///      بازمحاسبه می‌شود.
    /// نیاز به SQL Server زنده دارد؛ اگر پیدا نشد Skip. الگو: ItemPickerDbTests.
    /// </summary>
    public class SeedCleanupTests
    {
        private const string ScriptPath = "../../../../tools/seed-cleanup.sql";

        private static string CleanupScript()
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, ScriptPath));

        private static string ConnString()
            => Environment.GetEnvironmentVariable("TARAZIN_TEST_CONN")
               ?? "Server=localhost;Database=TarazinMaster;User Id=sa;Password=123456;TrustServerCertificate=True";

        /// <summary>Seed: شرکت تستی + کالا + نمونه‌ها + کنترل‌های سید اصلی.</summary>
        private static async Task<(SqlConnection cn, int companyId, int itemId, int sampleMvId, int sampleLayerId,
            int invId, int chequeId, int cashId, int docId, int keepMvId, int keepInvId, int keepChequeId, int keepDocId)>
            SeedAsync()
        {
            var cn = new SqlConnection(ConnString());
            await cn.OpenAsync();

            var companyId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست seed-cleanup', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            var itemId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Items (ItemCode, ItemTitle, Unit, StockQty, IsDeleted, CreatedAt, CompanyId, CreatedBy)
                VALUES (@Key, N'کالای تست', N'گرم', 100, 0, SYSUTCDATETIME(), @CompanyId, N'diag');
                SELECT SCOPE_IDENTITY();",
                new { Key = $"CLN-{Guid.NewGuid():N}"[..18], CompanyId = companyId });

            // ── نمونه‌ها (باید پاک شوند) ───────────────────────────────
            // ۱) حرکت انبار با توضیح «نمونه» + لایهٔ FIFO مرتبط
            var sampleMvId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Movements (MovementNumber, MovementType, ItemId, Qty, UnitPrice, MovementDate,
                    Description, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'MV-TEST-1', N'Receipt', @ItemId, 100, 1000, CAST(SYSDATETIME() AS DATE),
                    N'رسید نمونه: خرید برای تست cleanup', N'Posted', SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { ItemId = itemId, CompanyId = companyId });

            var sampleLayerId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.StockLayers (ItemId, WarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
                VALUES (@ItemId, 1, @MvId, 40, 1000, CAST(SYSDATETIME() AS DATE), @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { ItemId = itemId, MvId = sampleMvId, CompanyId = companyId });

            // ۲) حرکت «حواله بابت GINV-» (مربوط به فاکتور طلای نمونه)
            await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Movements (MovementNumber, MovementType, ItemId, Qty, UnitPrice, MovementDate,
                    Description, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'MV-TEST-2', N'Issue', @ItemId, 2, 1000, CAST(SYSDATETIME() AS DATE),
                    N'حواله بابت GINV-99999', N'Posted', SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { ItemId = itemId, CompanyId = companyId });

            // ۳) فاکتور طلای نمونه (XAU-24) + خط + دفتر طرف‌حساب
            var invId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO goldshop.SaleInvoices (InvoiceNumber, InvoiceDate, CustomerName, ItemCode, WeightGram,
                    Workmanship, Profit, Tax, TotalAmount, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'GINV-99999', CAST(SYSDATETIME() AS DATE), N'مشتری تست', N'XAU-24', 2, 0, 0, 0, 1000,
                    N'Issued', SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            await cn.ExecuteAsync(@"
                INSERT INTO goldshop.InvoiceLines (CompanyId, InvoiceId, RowType, ItemCode, Title, Qty, Price,
                    TaxEnabled, LineBase, LineTax, LineTotal)
                VALUES (@CompanyId, @InvoiceId, N'Gold', N'XAU-24', N'طلای ۲۴ تست', 2, 500, 0, 1000, 0, 1000);",
                new { CompanyId = companyId, InvoiceId = invId });

            await cn.ExecuteAsync(@"
                INSERT INTO goldshop.GoldPartyLedger (CompanyId, PartyId, InvoiceId, EntryDate, EntryType,
                    DebitRial, CreditRial, DebitGoldGram, CreditGoldGram, CreatedAt, CreatedBy)
                VALUES (@CompanyId, 1, @InvoiceId, CAST(SYSDATETIME() AS DATE), N'Sale', 1000, 0, 0, 2,
                    SYSUTCDATETIME(), N'seed');",
                new { CompanyId = companyId, InvoiceId = invId });

            // ۴) چک نمونه CHQ-SAMPLE
            var chequeId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO treasury.Cheques (ChequeNumber, Amount, DueDate, Direction, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'CHQ-SAMPLE-TEST', 1000, DATEADD(DAY, 15, CAST(SYSDATETIME() AS DATE)), N'In', N'Pending',
                    SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            // ۵) حرکت صندوق نمونه (دریافت)
            var cashId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO treasury.CashMovements (MovementNumber, MovementDate, Direction, Amount, CurrencyCode,
                    Description, SourceReference, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'CSH-TEST', CAST(SYSDATETIME() AS DATE), N'In', 1000, N'IRR',
                    N'دریافت نمونه: تست cleanup', N'', N'Posted', SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            // ۶) سند حسابداری نمونه (خط با GINV)
            var docId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.Documents (DocumentNumber, DocumentDate, DocumentType, CounterPartyName,
                    TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId)
                VALUES (N'00000123', CAST(SYSDATETIME() AS DATE), N'TreasuryIn', N'مشتری تست', 1000, N'IRR',
                    N'Note', SYSUTCDATETIME(), N'seed', 0, @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            await cn.ExecuteAsync(@"
                INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit, CreatedAt, CompanyId)
                VALUES (@DocId, 1, N'1010', N'صندوق', N'دریافت بابت GINV-99999', 1000, 0, SYSUTCDATETIME(), @CompanyId);",
                new { DocId = docId, CompanyId = companyId });

            // ── کنترل‌های سید اصلی (نباید پاک شوند) ─────────────────────
            // ۷) حرکت بدون نشانگر (فقط CreatedBy=seed)
            var keepMvId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Movements (MovementNumber, MovementType, ItemId, Qty, UnitPrice, MovementDate,
                    Description, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'MV-KEEP-1', N'Receipt', @ItemId, 10, 500, CAST(SYSDATETIME() AS DATE),
                    N'رسید سیستم اصلی', N'Posted', SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { ItemId = itemId, CompanyId = companyId });

            // ۸) فاکتور سید اصلی (XAU-18 / GINV-00001)
            var keepInvId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO goldshop.SaleInvoices (InvoiceNumber, InvoiceDate, CustomerName, ItemCode, WeightGram,
                    Workmanship, Profit, Tax, TotalAmount, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'GINV-00001', CAST(SYSDATETIME() AS DATE), N'مشتری نمونه', N'XAU-18', 5, 0, 0, 0, 5000,
                    N'Issued', SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            // ۹) چک عادی (بدون CHQ-SAMPLE)
            var keepChequeId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO treasury.Cheques (ChequeNumber, Amount, DueDate, Direction, Status, CreatedAt, CreatedBy, CompanyId)
                VALUES (N'CHQ-REG-0001', 2000, DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE)), N'In', N'Pending',
                    SYSUTCDATETIME(), N'seed', @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            // ۱۰) سند عادی (بدون خط GINV/نمونه)
            var keepDocId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO accounting.Documents (DocumentNumber, DocumentDate, DocumentType, CounterPartyName,
                    TotalAmount, CurrencyCode, Status, CreatedAt, CreatedBy, IsDeleted, CompanyId)
                VALUES (N'00000124', CAST(SYSDATETIME() AS DATE), N'OpeningBalance', N'سید اصلی', 500, N'IRR',
                    N'Note', SYSUTCDATETIME(), N'seed', 0, @CompanyId);
                SELECT SCOPE_IDENTITY();",
                new { CompanyId = companyId });

            await cn.ExecuteAsync(@"
                INSERT INTO accounting.DocumentLines (DocumentId, AccountId, AccountCode, Title, Description, Debit, Credit, CreatedAt, CompanyId)
                VALUES (@DocId, 1, N'1010', N'صندوق', N'تراز افتتاحیه', 500, 0, SYSUTCDATETIME(), @CompanyId);",
                new { DocId = keepDocId, CompanyId = companyId });

            return (cn, companyId, itemId, sampleMvId, sampleLayerId, invId, chequeId, cashId, docId,
                keepMvId, keepInvId, keepChequeId, keepDocId);
        }

        private static async Task CleanupAsync(SqlConnection cn, int companyId)
        {
            try
            {
                // حذف همهٔ seed های این تست در ترتیب امن FK
                await cn.ExecuteAsync(@"
                    DELETE dl FROM accounting.DocumentLines dl
                    JOIN accounting.Documents d ON d.DocumentId = dl.DocumentId WHERE d.CompanyId = @C;
                    DELETE FROM accounting.Documents WHERE CompanyId = @C;
                    DELETE FROM treasury.CashMovements WHERE CompanyId = @C;
                    DELETE FROM treasury.Cheques WHERE CompanyId = @C;
                    DELETE FROM goldshop.GoldPartyLedger WHERE CompanyId = @C;
                    DELETE FROM goldshop.InvoiceLines WHERE CompanyId = @C;
                    DELETE FROM goldshop.SaleInvoices WHERE CompanyId = @C;
                    DELETE FROM inventory.StockLayers WHERE CompanyId = @C;
                    DELETE FROM inventory.Movements WHERE CompanyId = @C;
                    DELETE FROM inventory.Items WHERE CompanyId = @C;
                    DELETE FROM central.Companies WHERE CompanyId = @C;",
                    new { C = companyId });
            }
            catch
            {
                // پاک‌سازی بهترین تلاش است
            }
            finally
            {
                await cn.DisposeAsync();
            }
        }

        /// <summary>اجرای seed-cleanup.sql با جای‌گذاری CompanyId (خروجی sqlcmd: پارامتر $(CompanyId)).</summary>
        private static async Task RunCleanupAsync(SqlConnection cn, int companyId)
        {
            var sql = CleanupScript()
                .Replace("$(CompanyId)", companyId.ToString())
                .Replace("GO", ""); // Dapper نمی‌تواند جداکنندهٔ GO را اجرا کند
            await cn.ExecuteAsync(sql);
        }

        [SkippableFact]
        public async Task SeedCleanup_RemovesSampleArtifacts_KeepsCoreSeed()
        {
            var (cn, companyId, itemId, sampleMvId, sampleLayerId, invId, chequeId, cashId, docId,
                keepMvId, keepInvId, keepChequeId, keepDocId) = await SeedAsync();
            try
            {
                // Act — اجرای همان اسکریپتی که seed-demo-data.sh --reseed صدا می‌زند
                await RunCleanupAsync(cn, companyId);

                // ── نمونه‌ها حذف/باطل شده‌اند ──────────────────────────
                Assert.Equal(1, await cn.ExecuteScalarAsync<int>(
                    "SELECT IsDeleted FROM inventory.Movements WHERE MovementId = @Id", new { Id = sampleMvId }));
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM inventory.StockLayers WHERE LayerId = @Id", new { Id = sampleLayerId }));
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM goldshop.SaleInvoices WHERE InvoiceId = @Id", new { Id = invId }));
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM goldshop.InvoiceLines WHERE InvoiceId = @Id", new { Id = invId }));
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM goldshop.GoldPartyLedger WHERE InvoiceId = @Id", new { Id = invId }));
                Assert.Equal("Voided", await cn.ExecuteScalarAsync<string>(
                    "SELECT Status FROM treasury.Cheques WHERE ChequeId = @Id", new { Id = chequeId }));
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM treasury.CashMovements WHERE MovementId = @Id", new { Id = cashId }));
                Assert.Equal(1, await cn.ExecuteScalarAsync<int>(
                    "SELECT IsDeleted FROM accounting.Documents WHERE DocumentId = @Id", new { Id = docId }));

                // ── کنترل‌های سید اصلی دست‌نخورده‌اند ───────────────────
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT IsDeleted FROM inventory.Movements WHERE MovementId = @Id", new { Id = keepMvId }));
                Assert.Equal(1, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM goldshop.SaleInvoices WHERE InvoiceId = @Id", new { Id = keepInvId }));
                Assert.Equal("Pending", await cn.ExecuteScalarAsync<string>(
                    "SELECT Status FROM treasury.Cheques WHERE ChequeId = @Id", new { Id = keepChequeId }));
                Assert.Equal(0, await cn.ExecuteScalarAsync<int>(
                    "SELECT IsDeleted FROM accounting.Documents WHERE DocumentId = @Id", new { Id = keepDocId }));

                // ── بازمحاسبهٔ StockQty: لایهٔ sample حذف شد → فقط لایهٔ کنترل
                //    (بدون لایهٔ کنترل باقی‌مانده برای این item → StockQty = 0؟)
                //    در Seed فقط یک لایه (sample) داریم؛ انتظار: 0.
                Assert.Equal(0m, await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId = @Id", new { Id = itemId }));
            }
            finally
            {
                await CleanupAsync(cn, companyId);
            }
        }

        [SkippableFact]
        public async Task SeedCleanup_RecomputesStock_FromRemainingLayers()
        {
            var (cn, companyId, itemId, sampleMvId, sampleLayerId, invId, chequeId, cashId, docId,
                keepMvId, keepInvId, keepChequeId, keepDocId) = await SeedAsync();
            try
            {
                // لایهٔ کنترل اضافه (نباید پاک شود) — موجودی واقعی 25 گرم
                var keepLayerId = await cn.ExecuteScalarAsync<int>(@"
                    INSERT INTO inventory.StockLayers (ItemId, WarehouseId, ReceiptMovementId, QtyRemaining, UnitCost, ReceivedDate, CompanyId)
                    VALUES (@ItemId, 1, @MvId, 25, 500, CAST(SYSDATETIME() AS DATE), @CompanyId);
                    SELECT SCOPE_IDENTITY();",
                    new { ItemId = itemId, MvId = keepMvId, CompanyId = companyId });

                await RunCleanupAsync(cn, companyId);

                // لایهٔ sample حذف شده؛ لایهٔ کنترل 25 گرم باقی است → StockQty باید 25 شود
                Assert.Equal(25m, await cn.ExecuteScalarAsync<decimal>(
                    "SELECT StockQty FROM inventory.Items WHERE ItemId = @Id", new { Id = itemId }));
                Assert.Equal(1, await cn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM inventory.StockLayers WHERE LayerId = @Id", new { Id = keepLayerId }));
            }
            finally
            {
                await CleanupAsync(cn, companyId);
            }
        }
    }
}
