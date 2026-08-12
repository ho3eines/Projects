using Dapper;
using Microsoft.Data.SqlClient;

namespace WebApi.Services;

/// <summary>
/// ساخت/ارتقای خودکار جدول Projects در دیتابیس اصلی webapi.
/// در Startup فراخوانی می‌شود تا جدول و ستون‌ها همیشه موجود باشند.
/// </summary>
public static class ProjectsTableInitializer
{
    public const string CreateTableSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Projects')
BEGIN
    CREATE TABLE [dbo].[Projects] (
        [ProjectGuid]               UNIQUEIDENTIFIER PRIMARY KEY,
        [Name]                      NVARCHAR(200)   NOT NULL,
        [Schema]                    NVARCHAR(50)    NOT NULL DEFAULT 'dbo',
        [LoginTokenHash]            NVARCHAR(128)   NOT NULL,
        [EncryptionKey]             NVARCHAR(256)   NOT NULL,
        [ApiKey]                    NVARCHAR(256)   NOT NULL,
        [SessionTimeoutMinutes]     INT             NOT NULL DEFAULT 10,
        [IsActive]                  BIT             NOT NULL DEFAULT 1,
        [ConnectionString]          NVARCHAR(MAX)   NOT NULL,
        [DatabaseName]              NVARCHAR(128)   NOT NULL DEFAULT '',
        [DatabaseProvider]          NVARCHAR(50)    NOT NULL DEFAULT 'SqlServer',
        [AutoBackupEnabled]         BIT             NOT NULL DEFAULT 0,
        [AutoBackupIntervalMinutes] INT             NOT NULL DEFAULT 1440,
        [AutoBackupTimeUtc]         TIME            NULL,
        [MaxBackupRetention]        INT             NOT NULL DEFAULT 7,
        [CreatedAtUtc]              DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        [LastBackupAtUtc]           DATETIME2       NULL,
        [Description]               NVARCHAR(500)   NULL,
        [Icon]                      NVARCHAR(100)   NULL,
        [ClientUrl]                 NVARCHAR(500)   NULL
    );
END
";

    /// <summary>ستون‌هایی که بعداً اضافه شده‌اند — برای ارتقای جدول موجود</summary>
    private static readonly (string Column, string Definition)[] UpgradeColumns =
    {
        ("ConnectionString", "NVARCHAR(MAX) NOT NULL DEFAULT ''"),
        ("DatabaseName", "NVARCHAR(128) NOT NULL DEFAULT ''"),
        ("DatabaseProvider", "NVARCHAR(50) NOT NULL DEFAULT 'SqlServer'"),
        ("AutoBackupEnabled", "BIT NOT NULL DEFAULT 0"),
        ("AutoBackupIntervalMinutes", "INT NOT NULL DEFAULT 1440"),
        ("AutoBackupTimeUtc", "TIME NULL"),
        ("MaxBackupRetention", "INT NOT NULL DEFAULT 7"),
        ("LastBackupAtUtc", "DATETIME2 NULL"),
        ("ClientUrl", "NVARCHAR(500) NULL")
    };

    public static async Task EnsureAsync(string connectionString)
    {
        try
        {
            await using var conn = new SqlConnection(connectionString);
            await conn.OpenAsync();
            await conn.ExecuteAsync(CreateTableSql);

            // ارتقای ستون‌های موجود
            foreach (var (name, definition) in UpgradeColumns)
            {
                var exists = await conn.ExecuteScalarAsync<int>(
                    @"SELECT COUNT(*) FROM sys.columns c
                      JOIN sys.tables t ON c.object_id = t.object_id
                      WHERE t.name = 'Projects' AND c.name = @name",
                    new { name });
                if (exists == 0)
                {
                    await conn.ExecuteAsync($"ALTER TABLE [dbo].[Projects] ADD [{name}] {definition}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ProjectsTableInitializer] Failed: {ex.Message}");
        }
    }
}