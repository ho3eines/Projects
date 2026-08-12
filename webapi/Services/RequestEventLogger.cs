using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Controllers;

/// <summary>یک رویداد درخواست — ثبت‌شده در جدول RequestEvents</summary>
public sealed class RequestEvent
{
    public Guid CorrelationId { get; set; }
    public string ApiKey { get; set; } = default!;
    public Guid ProjectGuid { get; set; }
    public Guid? UserId { get; set; }
    public string Endpoint { get; set; } = default!;
    public int StatusCode { get; set; }
    public long DurationMs { get; set; }
    public long CpuTimeMs { get; set; }
    public double RamUsedMb { get; set; }
    public DateTime TimestampUtc { get; set; }
    public string? ErrorMessage { get; set; }
}

/// <summary>
/// ثبت تمام رویدادهای API در جدول RequestEvents (خودکار ساخته می‌شود).
/// اجازه می‌دهد مدیر در UI زنده از وضعیت، خطاها، CPU/RAM و پروژه‌ها مطلع شود.
/// </summary>
public sealed class RequestEventLogger
{
    private const string CreateTableSql = @"
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'audit')
    EXEC(N'CREATE SCHEMA [audit]');

IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = N'audit' AND t.name = N'RequestEvents')
BEGIN
    CREATE TABLE [audit].[RequestEvents] (
        [Id]            BIGINT IDENTITY(1,1) PRIMARY KEY,
        [CorrelationId] UNIQUEIDENTIFIER NOT NULL,
        [ApiKey]        NVARCHAR(100)    NOT NULL,
        [ProjectGuid]   UNIQUEIDENTIFIER NOT NULL,
        [UserId]        UNIQUEIDENTIFIER NULL,
        [Endpoint]      NVARCHAR(300)    NOT NULL,
        [StatusCode]    INT              NOT NULL,
        [DurationMs]    BIGINT           NOT NULL,
        [CpuTimeMs]     BIGINT           NOT NULL DEFAULT 0,
        [RamUsedMb]     DECIMAL(10,2)    NOT NULL DEFAULT 0,
        [TimestampUtc]  DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
        [ErrorMessage]  NVARCHAR(MAX)    NULL
    );
    CREATE INDEX IX_RequestEvents_ProjectGuid ON [audit].[RequestEvents] ([ProjectGuid], [TimestampUtc] DESC);
    CREATE INDEX IX_RequestEvents_Status     ON [audit].[RequestEvents] ([StatusCode], [TimestampUtc] DESC);
END";

    private readonly string _connStr;
    private readonly ILogger<RequestEventLogger> _log;

    public RequestEventLogger(IOptions<RequestServiceConfig> cfg, ILogger<RequestEventLogger> log)
    {
        _connStr = cfg.Value.ConnectionString ?? string.Empty;
        _log = log;
        try
        {
            using var conn = new SqlConnection(_connStr);
            conn.Open();
            conn.Execute(CreateTableSql);
            _log.LogInformation("RequestEvents audit table is ready");
        }
        catch (Exception ex)
        {
            _log.LogWarning("Could not initialize RequestEvents table: {Error}", ex.Message);
        }
    }

    /// <summary>ثبت رویداد — هرگز exception نمی‌سازد تا جریان اصلی درخواست مختل نشود</summary>
    public async Task LogAsync(RequestEvent evt)
    {
        try
        {
            using var conn = new SqlConnection(_connStr);
            await conn.ExecuteAsync(@"
INSERT INTO [audit].[RequestEvents]
    (CorrelationId, ApiKey, ProjectGuid, UserId, Endpoint, StatusCode, DurationMs, CpuTimeMs, RamUsedMb, TimestampUtc, ErrorMessage)
VALUES
    (@CorrelationId, @ApiKey, @ProjectGuid, @UserId, @Endpoint, @StatusCode, @DurationMs, @CpuTimeMs, @RamUsedMb, @TimestampUtc, @ErrorMessage)",
                evt);
        }
        catch (Exception ex)
        {
            _log.LogWarning("Failed to write RequestEvent {Correlation}: {Error}", evt.CorrelationId, ex.Message);
        }
    }
}