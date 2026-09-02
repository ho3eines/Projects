using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests
{
    /// <summary>
    /// تست‌های دیتابیسی فیلتر انبار در جستجوی فاکتورها:
    ///   PurchaseInvoiceSearch / SalesInvoiceSearch باید فقط فاکتورهای
    ///   انبارِ درخواستی را برگردانند؛ مقدار 0/NULL یعنی همهٔ انبارها.
    /// نیاز به SQL Server زنده دارد؛ اگر پیدا نشد Skip. الگو: ItemPickerDbTests.
    /// </summary>
    public class WarehouseFilterTests
    {
        private static string Script(string name)
            => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "../../../../Tarazin.Data/Scripts/inventory", name));

        private static string ConnString()
            => Environment.GetEnvironmentVariable("TARAZIN_TEST_CONN")
               ?? "Server=localhost;Database=TarazinMaster;User Id=sa;Password=123456;TrustServerCertificate=True";

        private sealed class Seed
        {
            public required SqlConnection Cn;
            public required int CompanyId;
            public required int Wh1;
            public required int Wh2;
            public required int PurchaseInvoiceId;
            public required int SalesInvoiceId;
        }

        private static async Task<Seed> SeedAsync(string key)
        {
            var cn = new SqlConnection(ConnString());
            await cn.OpenAsync();
            var companyId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO central.Companies (CompanyName, IsActive, IsDeleted, CreatedAt, CreatedBy)
                VALUES (N'شرکت تست فیلتر انبار', 1, 0, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();");

            // دو انبار متعلق به همان شرکت (کد انبار درون شرکت یکتاست)
            var wh1 = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CreatedAt, CompanyId, CreatedBy)
                VALUES (@Code + N'-A', N'انبار اول', 1, 0, SYSUTCDATETIME(), @CompanyId, N'diag');
                SELECT SCOPE_IDENTITY();", new { Code = key, CompanyId = companyId });
            var wh2 = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Warehouses (WarehouseCode, Title, IsActive, IsDeleted, CreatedAt, CompanyId, CreatedBy)
                VALUES (@Code + N'-B', N'انبار دوم', 1, 0, SYSUTCDATETIME(), @CompanyId, N'diag');
                SELECT SCOPE_IDENTITY();", new { Code = key, CompanyId = companyId });

            // فاکتور خرید در انبار اول و فاکتور فروش در انبار دوم (جدول یکپارچه)
            var purchaseId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Invoices (OperationType, InvoiceNumber, InvoiceDate, SupplierName,
                                               WarehouseId, Status, CompanyId, CreatedAt, CreatedBy)
                VALUES (N'Purchase', @Number + N'/P', CAST(SYSUTCDATETIME() AS DATE), N'تأمین‌کننده تست',
                        @Wh1, N'Approved', @CompanyId, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", new { Number = key, Wh1 = wh1, CompanyId = companyId });
            var salesId = await cn.ExecuteScalarAsync<int>(@"
                INSERT INTO inventory.Invoices (OperationType, InvoiceNumber, InvoiceDate, CustomerName,
                                               WarehouseId, Status, SaleType, CompanyId, CreatedAt, CreatedBy)
                VALUES (N'Sales', @Number + N'/S', CAST(SYSUTCDATETIME() AS DATE), N'مشتری تست',
                        @Wh2, N'Approved', N'Retail', @CompanyId, SYSUTCDATETIME(), N'diag');
                SELECT SCOPE_IDENTITY();", new { Number = key, Wh2 = wh2, CompanyId = companyId });

            return new Seed { Cn = cn, CompanyId = companyId, Wh1 = wh1, Wh2 = wh2,
                              PurchaseInvoiceId = purchaseId, SalesInvoiceId = salesId };
        }

        private static async Task CleanupAsync(SqlConnection cn, int companyId, string key)
        {
            try
            {
                await cn.ExecuteAsync("DELETE FROM inventory.Invoices WHERE CompanyId = @CompanyId;", new { CompanyId = companyId });
                await cn.ExecuteAsync("DELETE FROM inventory.Warehouses WHERE CompanyId = @CompanyId;", new { CompanyId = companyId });
                await cn.ExecuteAsync("DELETE FROM central.Companies WHERE CompanyId = @CompanyId;", new { CompanyId = companyId });
            }
            catch (Exception exc)
            {
                Console.WriteLine($"cleanup failed ({key}): {exc.Message}");
            }
        }

        [SkippableFact]
        public async Task PurchaseSearch_FiltersByWarehouse_AndAll_Mode()
        {
            var key = "WHF" + Guid.NewGuid().ToString("N")[..8].ToUpperInvariant();
            var seed = await SeedAsync(key);
            try
            {
                // فقط انبار اول → فقط فاکتور خریدِ همان انبار
                var byWh1 = (await seed.Cn.QueryAsync(Script("PurchaseInvoiceSearch.sql"), new
                {
                    CompanyId = seed.CompanyId,
                    WarehouseId = seed.Wh1,
                    FromDate = (DateTime?)null, ToDate = (DateTime?)null,
                    Status = (string?)null, SupplierPartyId = (int?)null, Search = ""
                })).ToList();
                Assert.Single(byWh1);
                Assert.Equal(seed.PurchaseInvoiceId, (int)byWh1[0].PurchaseInvoiceId);

                // انبار دوم → هیچ فاکتور خریدی ندارد
                var byWh2 = (await seed.Cn.QueryAsync(Script("PurchaseInvoiceSearch.sql"), new
                {
                    CompanyId = seed.CompanyId,
                    WarehouseId = seed.Wh2,
                    FromDate = (DateTime?)null, ToDate = (DateTime?)null,
                    Status = (string?)null, SupplierPartyId = (int?)null, Search = ""
                })).ToList();
                Assert.Empty(byWh2);

                // صفر → همهٔ انبارها (فقط همین یک فاکتور خرید در شرکت)
                var all = (await seed.Cn.QueryAsync(Script("PurchaseInvoiceSearch.sql"), new
                {
                    CompanyId = seed.CompanyId,
                    WarehouseId = 0,
                    FromDate = (DateTime?)null, ToDate = (DateTime?)null,
                    Status = (string?)null, SupplierPartyId = (int?)null, Search = ""
                })).ToList();
                Assert.Single(all);
                Assert.Equal(seed.PurchaseInvoiceId, (int)all[0].PurchaseInvoiceId);
            }
            finally
            {
                await CleanupAsync(seed.Cn, seed.CompanyId, key);
                await seed.Cn.DisposeAsync();
            }
        }

        [SkippableFact]
        public async Task SalesSearch_FiltersByWarehouse()
        {
            var key = "WHS" + Guid.NewGuid().ToString("N")[..8].ToUpperInvariant();
            var seed = await SeedAsync(key);
            try
            {
                var byWh2 = (await seed.Cn.QueryAsync(Script("SalesInvoiceSearch.sql"), new
                {
                    CompanyId = seed.CompanyId,
                    WarehouseId = seed.Wh2,
                    FromDate = (DateTime?)null, ToDate = (DateTime?)null,
                    Status = (string?)null, CustomerPartyId = (int?)null, Search = ""
                })).ToList();
                Assert.Single(byWh2);
                Assert.Equal(seed.SalesInvoiceId, (int)byWh2[0].SalesInvoiceId);

                var byWh1 = (await seed.Cn.QueryAsync(Script("SalesInvoiceSearch.sql"), new
                {
                    CompanyId = seed.CompanyId,
                    WarehouseId = seed.Wh1,
                    FromDate = (DateTime?)null, ToDate = (DateTime?)null,
                    Status = (string?)null, CustomerPartyId = (int?)null, Search = ""
                })).ToList();
                Assert.Empty(byWh1);
            }
            finally
            {
                await CleanupAsync(seed.Cn, seed.CompanyId, key);
                await seed.Cn.DisposeAsync();
            }
        }
    }
}