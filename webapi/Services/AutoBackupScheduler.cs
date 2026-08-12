using System.Collections.Concurrent;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Controllers;

/// <summary>
/// زمان‌بند بکاپ خودکار:
/// - پروژه‌هایی که AutoBackupEnabled=true را در حافظه می‌گیرد
/// - هر ۱ دقیقه چک می‌کند: آیا زمان بکاپ رسیده؟ (بر اساس AutoBackupIntervalMinutes)
/// - بکاپ انجام می‌دهد و فایل را در wwwroot/backup/{ProjectGuid}/ می‌گذارد
/// - اضافه: اگر LastBackupAtUtc خیلی قدیمی باشد هم بکاپ می‌گیرد
/// </summary>
public sealed class AutoBackupScheduler : IHostedService, IDisposable
{
    private readonly RequestServiceConfig _cfg;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<AutoBackupScheduler> _log;

    private readonly ConcurrentDictionary<Guid, DateTime> _nextRunByProject = new();
    private Timer? _timer;

    public AutoBackupScheduler(
        IOptions<RequestServiceConfig> cfg,
        IWebHostEnvironment env,
        ILogger<AutoBackupScheduler> log)
    {
        _cfg = cfg.Value;
        _env = env;
        _log = log;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _timer = new Timer(Tick, null, TimeSpan.FromSeconds(30), TimeSpan.FromMinutes(1));
        _log.LogInformation("AutoBackupScheduler started (checking every 1 minute)");
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _timer?.Dispose();
        _timer = null;
        return Task.CompletedTask;
    }

    /// <summary>ثبت پروژه برای بکاپ خودکار — با خواندن تنظیمات از دیتابیس</summary>
    public async Task Register(Guid projectGuid)
    {
        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            var project = await conn.QueryFirstOrDefaultAsync<ProjectBackupConfig>(
                @"SELECT ProjectGuid, DatabaseName, ConnectionString, LastBackupAtUtc,
                         AutoBackupEnabled, AutoBackupIntervalMinutes, AutoBackupTimeUtc, MaxBackupRetention
                  FROM [dbo].[Projects] WHERE ProjectGuid = @guid", new { guid = projectGuid });

            if (project is null || !project.AutoBackupEnabled) { Unregister(projectGuid); return; }

            _nextRunByProject[projectGuid] = ComputeNextRun(project);
            _log.LogInformation("Auto-backup registered for {Project} (every {Interval} min)", projectGuid, project.AutoBackupIntervalMinutes);
        }
        catch (Exception ex)
        {
            _log.LogWarning("Failed to register auto-backup for {Project}: {Error}", projectGuid, ex.Message);
        }
    }

    public Task Unregister(Guid projectGuid)
    {
        _nextRunByProject.TryRemove(projectGuid, out _);
        return Task.CompletedTask;
    }

    /// <summary>ثبت همه پروژه‌های فعال — در Startup فراخوانی شود</summary>
    public async Task RegisterAllAsync()
    {
        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            // جدول ممکن است وجود نداشته باشد
            var exists = await conn.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM sys.tables WHERE name = 'Projects'");
            if (exists == 0) return;

            var projects = await conn.QueryAsync<Guid>(
                "SELECT ProjectGuid FROM [dbo].[Projects] WHERE AutoBackupEnabled = 1");
            foreach (var pid in projects)
                await Register(pid);
        }
        catch (Exception ex)
        {
            _log.LogWarning("RegisterAll failed: {Error}", ex.Message);
        }
    }

    // ===================== INTERNALS =====================

    private async void Tick(object? state)
    {
        foreach (var (projectGuid, nextRun) in _nextRunByProject.ToList())
        {
            if (DateTime.UtcNow < nextRun) continue;
            try
            {
                await RunBackupAsync(projectGuid);
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Auto-backup failed for {Project}", projectGuid);
            }
        }
    }

    private async Task RunBackupAsync(Guid projectGuid)
    {
        await using var conn = new SqlConnection(_cfg.ConnectionString);
        await conn.OpenAsync();
        var project = await conn.QueryFirstOrDefaultAsync<ProjectBackupConfig>(
            @"SELECT ProjectGuid, DatabaseName, ConnectionString, LastBackupAtUtc,
                     AutoBackupIntervalMinutes, AutoBackupTimeUtc, MaxBackupRetention
              FROM [dbo].[Projects] WHERE ProjectGuid = @guid AND AutoBackupEnabled = 1",
            new { guid = projectGuid });
        if (project is null) { Unregister(projectGuid); return; }

        // اجرای بکاپ
        var dir = Path.Combine(_env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot"),
            "backup", projectGuid.ToString());
        Directory.CreateDirectory(dir);
        var stamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var fileName = $"auto_{project.DatabaseName}_{stamp}.bak";
        var backupPath = Path.Combine(dir, fileName);

        var builder = new SqlConnectionStringBuilder(project.ConnectionString) { InitialCatalog = "master" };
        await using var master = new SqlConnection(builder.ConnectionString);
        await master.OpenAsync();
        await master.ExecuteAsync(
            "BACKUP DATABASE [{db}] TO DISK = @path WITH INIT, COMPRESSION",
            new { db = project.DatabaseName, path = backupPath });

        // به‌روزرسانی LastBackupAtUtc
        await conn.ExecuteAsync(
            "UPDATE [dbo].[Projects] SET LastBackupAtUtc = @now WHERE ProjectGuid = @guid",
            new { now = DateTime.UtcNow, guid = projectGuid });

        // Retention cleanup
        if (project.MaxBackupRetention > 0)
        {
            var all = Directory.GetFiles(dir, "*.bak")
                .Select(f => new FileInfo(f))
                .OrderByDescending(f => f.LastWriteTimeUtc)
                .ToList();
            foreach (var old in all.Skip(project.MaxBackupRetention))
            {
                try { old.Delete(); } catch { }
            }
        }

        _log.LogInformation("Auto-backup completed for {Project}: {File}", projectGuid, fileName);

        // محاسبه زمان بعدی
        _nextRunByProject[projectGuid] = DateTime.UtcNow.AddMinutes(project.AutoBackupIntervalMinutes);
    }

    private static DateTime ComputeNextRun(ProjectBackupConfig p)
    {
        var interval = p.AutoBackupIntervalMinutes > 0 ? p.AutoBackupIntervalMinutes : 1440;

        // اگر LastBackupAtUtc باشد → آخرین + interval
        if (p.LastBackupAtUtc.HasValue)
            return p.LastBackupAtUtc.Value.AddMinutes(interval);

        // اگر AutoBackupTimeUtc مشخص باشد → اولین زمان بعدی آن ساعت
        if (p.AutoBackupTimeUtc.HasValue)
        {
            var now = DateTime.UtcNow;
            var scheduled = now.Date.Add(p.AutoBackupTimeUtc.Value);
            if (scheduled <= now) scheduled = scheduled.AddDays(1);
            return scheduled;
        }

        // پیش‌فرض: ۱ دقیقه بعد (شروع سریع)
        return DateTime.UtcNow.AddMinutes(2);
    }

    public void Dispose()
    {
        _timer?.Dispose();
        _timer = null;
    }
}

/// <summary>پیکربندی بکاپ یک پروژه (خوانده‌شده از جدول)</summary>
public sealed class ProjectBackupConfig
{
    public Guid ProjectGuid { get; set; }
    public string DatabaseName { get; set; } = default!;
    public string ConnectionString { get; set; } = default!;
    public DateTime? LastBackupAtUtc { get; set; }
    public bool AutoBackupEnabled { get; set; }
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    public TimeSpan? AutoBackupTimeUtc { get; set; }
    public int MaxBackupRetention { get; set; } = 7;
}