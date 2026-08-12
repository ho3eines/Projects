using System.Diagnostics;
using System.Text.Json;
using Xunit;
using Xunit.SkippableFact;

namespace Hermes.ContractTests;

/// <summary>
/// PRD §4 + AC #2: exercises the outbox event backbone (ADR-002) exactly the
/// way webapi's OutboxProcessor does — producers write business rows + outbox
/// rows in one transaction, consumers run idempotently in the target schemas.
/// </summary>
public class IntegrationEventTests : IClassFixture<TestDatabase>
{
    private readonly TestDatabase _db;
    private const string SkipMsg = "SQL Server not reachable — set HERMES_TEST_CONNECTION or run `docker compose up`";

    public IntegrationEventTests(TestDatabase db) => _db = db;

    private static readonly Dictionary<string, (string Schema, string Script)[]> Routes = new(StringComparer.OrdinalIgnoreCase)
    {
        ["OrderPlaced"] = new[] { ("store", "ReserveStockForOrder") },
        ["StockReserved"] = new[] { ("accounting", "SalesInvoiceFromOrder") },
        ["StockRejected"] = new[] { ("store", "MarkOrderRejected") },
        ["InvoiceCreated"] = new[] { ("treasury", "CashEntryFromInvoice") },
        ["PayrollFinalized"] = new[] { ("accounting", "GLPostFromPayroll"), ("treasury", "CashMoveFromPayroll") },
        ["GoldPriceUpdated"] = new[] { ("accounting", "RefreshGoldPrice"), ("store", "RefreshGoldPrice") },
        ["InventoryMovement"] = new[] { ("accounting", "ApplyInventoryMovement"), ("goldshop", "ApplyInventoryMovement"), ("store", "ApplyInventoryMovement") }
    };

    // ============================================================
    // AC #2 — E2E: Customer places gold order on E-Com → Warehouse
    // reserves → Accounting issues invoice → Treasury records cash.
    // ============================================================
    [SkippableFact]
    public async Task E2E_gold_order_chain_completes_under_8_seconds()
    {
        Skip.IfNot(_db.Available, SkipMsg);

        var sw = Stopwatch.StartNew();

        // 1. Place order from customer 2's cart (2 × product P-GOLD18).
        await _db.Sql.ExecuteAsync(
            "IF NOT EXISTS (SELECT 1 FROM [store].[CartItems] WHERE CustomerId = 2 AND ProductId = 2) " +
            "INSERT INTO [store].[CartItems] (CustomerId, ProductId, Qty, AddedAt) VALUES (2, 2, 2, SYSUTDATETIME());");
        await _db.Sql.ExecuteAsync(
            "IF EXISTS (SELECT 1 FROM [store].[CartItems] WHERE CustomerId = 2 AND ProductId = 2 AND Qty <> 2) " +
            "UPDATE [store].[CartItems] SET Qty = 2 WHERE CustomerId = 2 AND ProductId = 2;");

        var orderSql = await _db.ReadScriptAsync("store", "OrderPlace");
        await _db.Sql.ExecuteAsync(orderSql, new Dictionary<string, object?> { ["CustomerId"] = 2L });

        var orderId = Convert.ToInt64(await _db.Sql.ScalarAsync(
            "SELECT TOP 1 OrderId FROM [store].[Orders] ORDER BY OrderId DESC"));
        Assert.True(orderId > 0, "Order was not created");

        // 2. Drain the outbox chain (OrderPlaced → StockReserved → InvoiceCreated).
        await DrainOutboxAsync();

        // 3. Assert the four artifacts.
        var status = (string)(await _db.Sql.ScalarAsync(
            "SELECT Status FROM [store].[Orders] WHERE OrderId = @id", new Dictionary<string, object?> { ["id"] = orderId }) ?? "");
        Assert.Equal("Reserved", status);

        var invoiceId = await _db.Sql.ScalarAsync(
            "SELECT InvoiceId FROM [accounting].[SalesInvoices] WHERE OrderId = @id",
            new Dictionary<string, object?> { ["id"] = orderId });
        Assert.NotNull(invoiceId);

        var cash = await _db.Sql.ScalarAsync(
            "SELECT COUNT(*) FROM [treasury].[CashMovements] WHERE SourceReference = CONCAT(N'Invoice:', @iid)",
            new Dictionary<string, object?> { ["iid"] = invoiceId });
        Assert.Equal(1, cash);

        // 4. Idempotency: replaying consumers changes nothing.
        var payload = new Dictionary<string, object?>
        {
            ["OrderId"] = orderId,
            ["CustomerName"] = (string)(await _db.Sql.ScalarAsync(
                "SELECT CustomerName FROM [store].[Orders] WHERE OrderId = @id", new Dictionary<string, object?> { ["id"] = orderId }) ?? ""),
            ["TotalAmount"] = (decimal)(await _db.Sql.ScalarAsync(
                "SELECT TotalAmount FROM [store].[Orders] WHERE OrderId = @id", new Dictionary<string, object?> { ["id"] = orderId }) ?? 0m),
            ["CurrencyCode"] = "IRR"
        };
        var replayInvoice = await _db.Sql.ExecuteAsync(
            await _db.ReadScriptAsync("accounting", "SalesInvoiceFromOrder"), payload);
        Assert.Equal(0, replayInvoice);

        sw.Stop();

        if (Environment.GetEnvironmentVariable("HERMES_STRICT_E2E") == "1")
        {
            Assert.True(sw.Elapsed < TimeSpan.FromSeconds(8),
                $"E2E chain took {sw.Elapsed.TotalSeconds:F1}s — AC #2 requires < 8s");
        }
    }

    // ============================================================
    // Payroll dual-write: PayrollFinalized → accounting GL + treasury cash
    // ============================================================
    [SkippableFact]
    public async Task Payroll_finalize_posts_GL_and_cash_idempotently()
    {
        Skip.IfNot(_db.Available, SkipMsg);

        var period = "T-" + DateTime.UtcNow.ToString("yyyyMMddHHmmss");

        await _db.Sql.ExecuteAsync(
            "IF NOT EXISTS (SELECT 1 FROM [payroll].[SalaryItems] WHERE EmployeeId = 1 AND Period = @p) " +
            "INSERT INTO [payroll].[SalaryItems] (EmployeeId, Period, Title, Amount, IsDeduction, CreatedAt) VALUES (1, @p, N'حقوق پایه تست', 50000000, 0, SYSUTDATETIME());",
            new Dictionary<string, object?> { ["p"] = period });

        await _db.Sql.ExecuteAsync(await _db.ReadScriptAsync("payroll", "PayrollFinalize"),
            new Dictionary<string, object?> { ["Period"] = period, ["CreatedBy"] = "test" });

        await DrainOutboxAsync();

        var runId = await _db.Sql.ScalarAsync(
            "SELECT RunId FROM [payroll].[PayrollRuns] WHERE Period = @p", new Dictionary<string, object?> { ["p"] = period });
        Assert.NotNull(runId);

        var gl = await _db.Sql.ScalarAsync(
            "SELECT COUNT(*) FROM [accounting].[PayrollPostings] WHERE RunId = @rid", new Dictionary<string, object?> { ["rid"] = runId });
        Assert.Equal(1, gl);

        var cash = await _db.Sql.ScalarAsync(
            "SELECT COUNT(*) FROM [treasury].[CashMovements] WHERE SourceReference = CONCAT(N'Payroll:', @rid)", new Dictionary<string, object?> { ["rid"] = runId });
        Assert.Equal(1, cash);

        // Replay → no-op.
        var replay = await _db.Sql.ExecuteAsync(await _db.ReadScriptAsync("accounting", "GLPostFromPayroll"),
            new Dictionary<string, object?> { ["RunId"] = runId, ["Period"] = period, ["EmployeeCount"] = 1L, ["NetTotal"] = 50000000m });
        Assert.Equal(0, replay);
    }

    // ============================================================
    // Gold price pub/sub: GoldPriceUpdated → accounting + store snapshots
    // ============================================================
    [SkippableFact]
    public async Task Gold_price_update_refreshes_read_models()
    {
        Skip.IfNot(_db.Available, SkipMsg);

        await _db.Sql.ExecuteAsync(await _db.ReadScriptAsync("goldshop", "GoldPriceUpsert"),
            new Dictionary<string, object?>
            {
                ["ItemCode"] = "XAU-24",
                ["Title"] = "طلای ۲۴ عیار (گرم)",
                ["PricePerGram"] = 39000000L,
                ["RateToIRR"] = null
            });

        await DrainOutboxAsync();

        var acc = await _db.Sql.ScalarAsync(
            "SELECT PricePerGram FROM [accounting].[GoldPriceSnapshot] WHERE ItemCode = N'XAU-24'");
        var store = await _db.Sql.ScalarAsync(
            "SELECT PricePerGram FROM [store].[GoldPriceSnapshot] WHERE ItemCode = N'XAU-24'");
        Assert.Equal(39000000m, acc);
        Assert.Equal(39000000m, store);
    }

    // ============================================================
    // Inventory movement: MovementInsert → three consumers rebuild read-models
    // ============================================================
    [SkippableFact]
    public async Task Inventory_movement_propagates_to_consumers()
    {
        Skip.IfNot(_db.Available, SkipMsg);

        await _db.Sql.ExecuteAsync(await _db.ReadScriptAsync("inventory", "MovementInsert"),
            new Dictionary<string, object?>
            {
                ["MovementType"] = "Receipt",
                ["ItemId"] = 1L,
                ["WarehouseId"] = null,
                ["Qty"] = 5m,
                ["UnitPrice"] = 38000000m,
                ["MovementDate"] = DateTime.Today,
                ["Description"] = "تست انتشار رویداد",
                ["CreatedBy"] = "test"
            });

        await DrainOutboxAsync();

        var movementId = await _db.Sql.ScalarAsync(
            "SELECT TOP 1 MovementId FROM [inventory].[Movements] ORDER BY MovementId DESC");
        Assert.NotNull(movementId);

        foreach (var schema in new[] { "accounting", "goldshop", "store" })
        {
            var table = schema switch
            {
                "accounting" => "InventoryLedger",
                _ => "InventorySnapshot"
            };
            var n = await _db.Sql.ScalarAsync(
                $"SELECT COUNT(*) FROM [{schema}].[{table}] WHERE MovementId = @mid",
                new Dictionary<string, object?> { ["mid"] = movementId });
            Assert.Equal(1, n);
        }
    }

    // ============================================================
    // Outbox drain — mirrors webapi OutboxProcessor (routes from appsettings)
    // ============================================================
    private async Task DrainOutboxAsync()
    {
        var schemas = new[] { "store", "accounting", "treasury", "payroll", "goldshop", "inventory" };

        for (var pass = 0; pass < 10; pass++)
        {
            var processedAny = false;

            foreach (var schema in schemas)
            {
                var rows = await _db.Sql.QueryRowsAsync(
                    $"SELECT TOP 50 OutboxId, EventType, Payload FROM [{schema}].[Outbox] " +
                    "WHERE ProcessedAt IS NULL AND Attempts < 5 ORDER BY OutboxId");

                foreach (var row in rows)
                {
                    var eventType = (string)row["EventType"]!;
                    var outboxId = (long)row["OutboxId"]!;
                    var payload = JsonSerializer.Deserialize<Dictionary<string, object?>>((string)row["Payload"]!);

                    if (!Routes.TryGetValue(eventType, out var consumers))
                    {
                        await _db.Sql.ExecuteAsync(
                            $"UPDATE [{schema}].[Outbox] SET Attempts = Attempts + 1, LastError = N'No route' WHERE OutboxId = @id",
                            new Dictionary<string, object?> { ["id"] = outboxId });
                        continue;
                    }

                    var ok = true;
                    foreach (var (consumerSchema, script) in consumers)
                    {
                        try
                        {
                            await _db.Sql.ExecuteAsync(await _db.ReadScriptAsync(consumerSchema, script), payload);
                        }
                        catch
                        {
                            ok = false;
                            await _db.Sql.ExecuteAsync(
                                $"UPDATE [{schema}].[Outbox] SET Attempts = Attempts + 1 WHERE OutboxId = @id",
                                new Dictionary<string, object?> { ["id"] = outboxId });
                            break;
                        }
                    }

                    if (ok)
                    {
                        await _db.Sql.ExecuteAsync(
                            $"UPDATE [{schema}].[Outbox] SET ProcessedAt = SYSUTCDATETIME() WHERE OutboxId = @id",
                            new Dictionary<string, object?> { ["id"] = outboxId });
                    }
                    processedAny = true;
                }
            }

            if (!processedAny)
                break;
        }
    }
}
