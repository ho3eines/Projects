using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public sealed class OutboxConsumer
{
    public string Schema { get; set; } = "";
    public string Script { get; set; } = "";
}

public sealed class OutboxRoute
{
    public string EventType { get; set; } = "";
    public List<OutboxConsumer> Consumers { get; set; } = new();
}

public sealed class OutboxOptions
{
    public int PollIntervalSeconds { get; set; } = 3;
    public int MaxAttempts { get; set; } = 5;
    public int BatchSize { get; set; } = 50;
    public List<OutboxRoute> Routes { get; set; } = new();
}

/// <summary>
/// Event backbone (PRD §4, ADR-002): polls each product schema's Outbox table
/// and dispatches events to consumer scripts in the target schemas.
/// Producers write business rows + outbox rows in one transaction; consumers
/// are idempotent (WHERE NOT EXISTS on EventKey). Delivery is at-least-once,
/// effect is exactly-once.
/// </summary>
public sealed class OutboxProcessor : BackgroundService
{
    private readonly ISystemQueryExecutor _executor;
    private readonly IProjectCatalog _projects;
    private readonly IAuditService _audit;
    private readonly OutboxOptions _options;
    private readonly string? _cs;
    private readonly ILogger<OutboxProcessor> _logger;
    private readonly Dictionary<string, List<OutboxConsumer>> _routes;

    public OutboxProcessor(
        ISystemQueryExecutor executor,
        IProjectCatalog projects,
        IAuditService audit,
        IOptions<ConnectionStringsOptions> connectionStrings,
        IOptions<OutboxOptions> options,
        ILogger<OutboxProcessor> logger)
    {
        _executor = executor;
        _projects = projects;
        _audit = audit;
        _cs = connectionStrings.Value.DefaultConnection;
        _options = options.Value;
        _logger = logger;
        _routes = new Dictionary<string, List<OutboxConsumer>>(StringComparer.OrdinalIgnoreCase);
        foreach (var route in _options.Routes)
        {
            if (string.IsNullOrWhiteSpace(route.EventType) || route.Consumers.Count == 0)
                continue;
            _routes[route.EventType] = route.Consumers;
        }
    }

    private sealed class OutboxRow
    {
        public long OutboxId { get; set; }
        public string EventType { get; set; } = "";
        public string EventKey { get; set; } = "";
        public string Payload { get; set; } = "";
        public int PayloadVersion { get; set; } = 1;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessOnceAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Outbox poll cycle failed");
            }

            await Task.Delay(TimeSpan.FromSeconds(Math.Clamp(_options.PollIntervalSeconds, 1, 60)), stoppingToken);
        }
    }

    private async Task ProcessOnceAsync(CancellationToken ct)
    {
        foreach (var project in _projects.AllActive())
        {
            var schema = project.Schema;
            if (string.Equals(schema, "central", StringComparison.OrdinalIgnoreCase))
                continue; // central has no outbox

            var rows = await FetchReadyAsync(schema, ct);
            foreach (var row in rows)
            {
                if (ct.IsCancellationRequested)
                    return;

                if (!_routes.TryGetValue(row.EventType, out var consumers))
                {
                    await MarkFailedAsync(schema, row.OutboxId, "No route for event type: " + row.EventType);
                    continue;
                }

                var ok = true;
                foreach (var consumer in consumers)
                {
                    try
                    {
                        object? prm;
                        using (var doc = JsonDocument.Parse(row.Payload))
                            prm = doc.RootElement.Clone();

                        await _executor.ExecuteAsync(consumer.Script, prm, consumer.Schema);
                        await _audit.LogAsync(new AuditEntry
                        {
                            SchemaName = consumer.Schema,
                            ScriptName = consumer.Script,
                            Parameters = row.Payload,
                            UserTokenId = "outbox",
                            RequestId = $"outbox:{row.OutboxId}:{row.EventType}",
                            Outcome = "Success"
                        });
                    }
                    catch (Exception ex)
                    {
                        ok = false;
                        _logger.LogWarning(ex, "Outbox consumer {Schema}/{Script} failed for event {Type} #{Id}",
                            consumer.Schema, consumer.Script, row.EventType, row.OutboxId);
                        await _audit.LogAsync(new AuditEntry
                        {
                            SchemaName = consumer.Schema,
                            ScriptName = consumer.Script,
                            Parameters = row.Payload,
                            UserTokenId = "outbox",
                            RequestId = $"outbox:{row.OutboxId}:{row.EventType}",
                            Outcome = "Error",
                            Error = ex.Message
                        });
                        await MarkFailedAsync(schema, row.OutboxId, ex.Message);
                        break;
                    }
                }

                if (ok)
                    await MarkProcessedAsync(schema, row.OutboxId);
            }
        }
    }

    private async Task<List<OutboxRow>> FetchReadyAsync(string schema, CancellationToken ct)
        {
            await using var conn = new SqlConnection(_cs);
            await conn.OpenAsync(ct);
        
            // Check if Outbox table exists in this schema
            var tableExists = await conn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = 'Outbox'",
                new { schema });
        
            if (tableExists == 0)
            {
                // No outbox table in this schema - skip silently
                return new List<OutboxRow>();
            }
        
            var rows = await conn.QueryAsync<OutboxRow>(
                $@"
    SELECT TOP (@BatchSize) OutboxId, EventType, EventKey, Payload, PayloadVersion
    FROM [{schema}].[Outbox]
    WHERE ProcessedAt IS NULL AND Attempts < @MaxAttempts
    ORDER BY OutboxId",
                new { BatchSize = _options.BatchSize, MaxAttempts = _options.MaxAttempts });
            return rows.AsList();
        }

    private async Task MarkProcessedAsync(string schema, long outboxId)
    {
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync();
        await conn.ExecuteAsync(
            $"UPDATE [{schema}].[Outbox] SET ProcessedAt = SYSUTCDATETIME() WHERE OutboxId = @id",
            new { id = outboxId });
    }

    private async Task MarkFailedAsync(string schema, long outboxId, string error)
    {
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync();
        await conn.ExecuteAsync(
            $"UPDATE [{schema}].[Outbox] SET Attempts = Attempts + 1, LastError = @err WHERE OutboxId = @id",
            new { id = outboxId, err = (error ?? "").Length <= 2000 ? error : error[..2000] });
    }
}
