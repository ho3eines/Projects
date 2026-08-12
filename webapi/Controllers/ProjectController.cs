using System.Text;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Controllers;

/// <summary>
/// مدیریت کامل پروژه‌ها:
/// - CRUD پروژه با ConnectionString اختصاصی هر پروژه
/// - بکاپ دیتابیس به wwwroot/backup/{ProjectGuid}/
/// - دانلود بکاپ / ریستور
/// - تنظیم بکاپ خودکار (AutoBackupScheduler)
/// </summary>
[ApiController]
[Route("api/projects")]
public class ProjectController : ControllerBase
{
    private readonly RequestServiceConfig _cfg;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<ProjectController> _log;
    private readonly AutoBackupScheduler _backupScheduler;

    public ProjectController(
        IOptions<RequestServiceConfig> cfg,
        IWebHostEnvironment env,
        ILogger<ProjectController> log,
        AutoBackupScheduler backupScheduler)
    {
        _cfg = cfg.Value;
        _env = env;
        _log = log;
        _backupScheduler = backupScheduler;
    }

    // ===================== CRUD =====================

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        if (!TryValidateApiKey(out var error)) return error;

        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            var projects = (await conn.QueryAsync<ProjectDefinition>(
                "SELECT * FROM [dbo].[Projects] ORDER BY [CreatedAtUtc] DESC")).ToList();
            var dto = projects.Select(p => new ProjectDefinitionDto
            {
                ProjectGuid = p.ProjectGuid,
                Name = p.Name,
                Schema = p.Schema,
                LoginTokenHash = p.LoginTokenHash,
                EncryptionKey = p.EncryptionKey,
                ApiKey = p.ApiKey,
                SessionTimeoutMinutes = p.SessionTimeoutMinutes,
                IsActive = p.IsActive,
                ConnectionString = p.ConnectionString,
                DatabaseName = p.DatabaseName,
                DatabaseProvider = p.DatabaseProvider,
                AutoBackupEnabled = p.AutoBackupEnabled,
                AutoBackupIntervalMinutes = p.AutoBackupIntervalMinutes,
                AutoBackupTimeUtc = p.AutoBackupTimeUtc,
                MaxBackupRetention = p.MaxBackupRetention,
                LastBackupAtUtc = p.LastBackupAtUtc,
                Description = p.Description,
                Icon = p.Icon
            }).ToList();
            return Ok(new ProjectListResponse { Projects = dto });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to get projects");
            return StatusCode(500, new { error = "Failed to get projects" });
        }
    }

    [HttpGet("{projectGuid:guid}")]
    public async Task<IActionResult> Get(Guid projectGuid)
    {
        if (!TryValidateApiKey(out var error)) return error;
        var project = await FindProjectAsync(projectGuid);
        if (project is null) return NotFound(new { error = "Project not found" });
        return Ok(project);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateProjectDto dto)
    {
        if (!TryValidateApiKey(out var error)) return error;

        if (string.IsNullOrWhiteSpace(dto.ConnectionString))
            return BadRequest(new { error = "ConnectionString is required" });
        if (string.IsNullOrWhiteSpace(dto.DatabaseName))
            dto.DatabaseName = ExtractDbName(dto.ConnectionString);
        if (dto.ProjectGuid == Guid.Empty)
            dto.ProjectGuid = Guid.NewGuid();

        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            await ProjectsTableInitializer.EnsureAsync(_cfg.ConnectionString);

            await conn.ExecuteAsync(@"
INSERT INTO [dbo].[Projects]
    (ProjectGuid, [Name], [Schema], LoginTokenHash, EncryptionKey, ApiKey,
     SessionTimeoutMinutes, IsActive, ConnectionString, DatabaseName, DatabaseProvider,
     AutoBackupEnabled, AutoBackupIntervalMinutes, AutoBackupTimeUtc, MaxBackupRetention,
     CreatedAtUtc, [Description], [Icon])
VALUES
    (@ProjectGuid, @Name, @Schema, @LoginTokenHash, @EncryptionKey, @ApiKey,
     @SessionTimeoutMinutes, @IsActive, @ConnectionString, @DatabaseName, @DatabaseProvider,
     @AutoBackupEnabled, @AutoBackupIntervalMinutes, @AutoBackupTimeUtc, @MaxBackupRetention,
     @CreatedAtUtc, @Description, @Icon)",
                new
                {
                    dto.ProjectGuid, dto.Name, dto.Schema, dto.LoginTokenHash, dto.EncryptionKey, dto.ApiKey,
                    dto.SessionTimeoutMinutes, dto.IsActive, dto.ConnectionString, dto.DatabaseName, dto.DatabaseProvider,
                    dto.AutoBackupEnabled, dto.AutoBackupIntervalMinutes, dto.AutoBackupTimeUtc, dto.MaxBackupRetention,
                    CreatedAtUtc = DateTime.UtcNow, dto.Description, dto.Icon
                });

            // ساخت پوشه بکاپ
            var backupDir = GetBackupDir(dto.ProjectGuid);
            Directory.CreateDirectory(backupDir);

            // ثبت در زمان‌بند بکاپ خودکار
            await _backupScheduler.Register(dto.ProjectGuid);

            return CreatedAtAction(nameof(Get), new { projectGuid = dto.ProjectGuid },
                new { message = "Project created", dto.ProjectGuid });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to create project");
            return StatusCode(500, new { error = "Failed to create project" });
        }
    }

    [HttpPut("{projectGuid:guid}")]
    public async Task<IActionResult> Update(Guid projectGuid, [FromBody] CreateProjectDto dto)
    {
        if (!TryValidateApiKey(out var error)) return error;

        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            var affected = await conn.ExecuteAsync(@"
UPDATE [dbo].[Projects] SET
    [Name] = @Name, [Schema] = @Schema, LoginTokenHash = @LoginTokenHash,
    EncryptionKey = @EncryptionKey, ApiKey = @ApiKey,
    SessionTimeoutMinutes = @SessionTimeoutMinutes, IsActive = @IsActive,
    ConnectionString = @ConnectionString, DatabaseName = @DatabaseName, DatabaseProvider = @DatabaseProvider,
    AutoBackupEnabled = @AutoBackupEnabled, AutoBackupIntervalMinutes = @AutoBackupIntervalMinutes,
    AutoBackupTimeUtc = @AutoBackupTimeUtc, MaxBackupRetention = @MaxBackupRetention,
    [Description] = @Description, [Icon] = @Icon
WHERE ProjectGuid = @ProjectGuid",
                new
                {
                    ProjectGuid = projectGuid, dto.Name, dto.Schema, dto.LoginTokenHash, dto.EncryptionKey, dto.ApiKey,
                    dto.SessionTimeoutMinutes, dto.IsActive, dto.ConnectionString, dto.DatabaseName, dto.DatabaseProvider,
                    dto.AutoBackupEnabled, dto.AutoBackupIntervalMinutes, dto.AutoBackupTimeUtc, dto.MaxBackupRetention,
                    dto.Description, dto.Icon
                });

            if (affected == 0) return NotFound(new { error = "Project not found" });

            await _backupScheduler.Register(projectGuid);
            return Ok(new { message = "Project updated", projectGuid });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to update project {ProjectGuid}", projectGuid);
            return StatusCode(500, new { error = "Failed to update project" });
        }
    }

    [HttpDelete("{projectGuid:guid}")]
    public async Task<IActionResult> Delete(Guid projectGuid)
    {
        if (!TryValidateApiKey(out var error)) return error;

        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            var affected = await conn.ExecuteAsync(
                "DELETE FROM [dbo].[Projects] WHERE ProjectGuid = @guid", new { guid = projectGuid });
            if (affected == 0) return NotFound(new { error = "Project not found" });

            await _backupScheduler.Unregister(projectGuid);
            return Ok(new { message = "Project deleted" });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to delete project {ProjectGuid}", projectGuid);
            return StatusCode(500, new { error = "Failed to delete project" });
        }
    }

    // ===================== BACKUP =====================

    /// <summary>بکاپ دستی — فایل .bak در wwwroot/backup/{ProjectGuid}/</summary>
    [HttpPost("{projectGuid:guid}/backup")]
    public async Task<IActionResult> Backup(Guid projectGuid, [FromQuery] bool auto = false)
    {
        if (!TryValidateApiKey(out var error)) return error;
        var project = await FindProjectAsync(projectGuid);
        if (project is null) return NotFound(new { error = "Project not found" });

        try
        {
            var result = await PerformBackupAsync(project, auto);
            if (!result.Success) return StatusCode(500, result);

            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            await conn.ExecuteAsync(
                "UPDATE [dbo].[Projects] SET LastBackupAtUtc = @now WHERE ProjectGuid = @guid",
                new { now = DateTime.UtcNow, guid = projectGuid });

            return Ok(result);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Backup failed for project {ProjectGuid}", projectGuid);
            return StatusCode(500, new BackupResultDto { Success = false, Error = ex.Message });
        }
    }

    /// <summary>لیست بکاپ‌های موجود برای دانلود</summary>
    [HttpGet("{projectGuid:guid}/backups")]
    public async Task<IActionResult> ListBackups(Guid projectGuid)
    {
        if (!TryValidateApiKey(out var error)) return error;
        var project = await FindProjectAsync(projectGuid);
        if (project is null) return NotFound(new { error = "Project not found" });

        var dir = GetBackupDir(projectGuid);
        if (!Directory.Exists(dir))
            return Ok(new BackupListResponse());

        var backups = Directory.GetFiles(dir, "*.bak")
            .Select(f => new FileInfo(f))
            .OrderByDescending(f => f.LastWriteTimeUtc)
            .Select(f => new BackupInfoDto
            {
                FileName = f.Name,
                SizeBytes = f.Length,
                CreatedAtUtc = f.LastWriteTimeUtc,
                DownloadUrl = $"/backup/{projectGuid}/{f.Name}",
                IsAutoBackup = f.Name.Contains("auto", StringComparison.OrdinalIgnoreCase)
            })
            .ToList();

        return Ok(new BackupListResponse { Total = backups.Count, Backups = backups });
    }

    /// <summary>دانلود بکاپ از wwwroot</summary>
    [HttpGet("{projectGuid:guid}/backups/{fileName}")]
    public IActionResult DownloadBackup(Guid projectGuid, string fileName)
    {
        // دانلود نیاز به API key ندارد تا آسان باشد (فقط نام فایل امن)
        var safeName = Path.GetFileName(fileName); // جلوگیری از path traversal
        var dir = GetBackupDir(projectGuid);
        var path = Path.Combine(dir, safeName);
        if (!System.IO.File.Exists(path))
            return NotFound(new { error = "Backup not found" });

        var fileBytes = System.IO.File.ReadAllBytes(path);
        return File(fileBytes, "application/octet-stream", safeName);
    }

    /// <summary>ریستور دیتابیس از بکاپ</summary>
    [HttpPost("{projectGuid:guid}/restore")]
    public async Task<IActionResult> Restore(Guid projectGuid, [FromBody] RestoreRequestDto dto)
    {
        if (!TryValidateApiKey(out var error)) return error;
        var project = await FindProjectAsync(projectGuid);
        if (project is null) return NotFound(new { error = "Project not found" });

        var safeName = Path.GetFileName(dto.BackupFileName);
        var dir = GetBackupDir(projectGuid);
        var backupPath = Path.Combine(dir, safeName);
        if (!System.IO.File.Exists(backupPath))
            return NotFound(new { error = "Backup file not found" });

        try
        {
            // ریستور با SQL Server: RESTORE DATABASE
            var dbName = project.DatabaseName;
            var masterConn = BuildMasterConnection(project.ConnectionString);

            await using var conn = new SqlConnection(masterConn);
            await conn.OpenAsync();

            // اطمینان از تنها بودن اتصال
            await conn.ExecuteAsync($@"
IF DB_ID('{dbName}') IS NOT NULL
BEGIN
    ALTER DATABASE [{dbName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    RESTORE DATABASE [{dbName}] FROM DISK = @backupPath WITH REPLACE;
    ALTER DATABASE [{dbName}] SET MULTI_USER;
END
ELSE
BEGIN
    RESTORE DATABASE [{dbName}] FROM DISK = @backupPath WITH REPLACE;
END",
                new { backupPath });

            return Ok(new { success = true, message = $"Database {dbName} restored from {safeName}" });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Restore failed for project {ProjectGuid} from {File}", projectGuid, safeName);
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    /// <summary>تنظیم بکاپ خودکار — بلافاصله در زمان‌بند ثبت می‌شود</summary>
    [HttpPut("{projectGuid:guid}/backup-settings")]
    public async Task<IActionResult> UpdateBackupSettings(Guid projectGuid, [FromBody] UpdateBackupSettingsDto dto)
    {
        if (!TryValidateApiKey(out var error)) return error;

        try
        {
            await using var conn = new SqlConnection(_cfg.ConnectionString);
            await conn.OpenAsync();
            var affected = await conn.ExecuteAsync(@"
UPDATE [dbo].[Projects] SET
    AutoBackupEnabled = @enabled,
    AutoBackupIntervalMinutes = @interval,
    AutoBackupTimeUtc = @time,
    MaxBackupRetention = @retention
WHERE ProjectGuid = @guid",
                new
                {
                    enabled = dto.AutoBackupEnabled,
                    interval = dto.AutoBackupIntervalMinutes > 0 ? dto.AutoBackupIntervalMinutes : 1440,
                    time = dto.AutoBackupTimeUtc,
                    retention = dto.MaxBackupRetention > 0 ? dto.MaxBackupRetention : 7,
                    guid = projectGuid
                });

            if (affected == 0) return NotFound(new { error = "Project not found" });

            // ثبت مجدد در زمان‌بند
            if (dto.AutoBackupEnabled)
                await _backupScheduler.Register(projectGuid);
            else
                await _backupScheduler.Unregister(projectGuid);

            return Ok(new { message = "Backup settings updated", dto });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Failed to update backup settings for {ProjectGuid}", projectGuid);
            return StatusCode(500, new { error = "Failed to update backup settings" });
        }
    }

    // ===================== HELPERS =====================

    private async Task<ProjectDefinition?> FindProjectAsync(Guid projectGuid)
    {
        await using var conn = new SqlConnection(_cfg.ConnectionString);
        await conn.OpenAsync();
        return await conn.QueryFirstOrDefaultAsync<ProjectDefinition>(
            "SELECT * FROM [dbo].[Projects] WHERE ProjectGuid = @guid", new { guid = projectGuid });
    }

    private bool TryValidateApiKey(out IActionResult error)
    {
        error = null!;
        if (!Request.Headers.TryGetValue("X-Api-Key", out var key) || !_cfg.ValidateApiKey(key!))
        {
            error = Unauthorized(new { error = "Invalid API Key" });
            return false;
        }
        return true;
    }

    private string GetBackupDir(Guid projectGuid)
    {
        var dir = Path.Combine(_env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot"), "backup", projectGuid.ToString());
        Directory.CreateDirectory(dir);
        return dir;
    }

    private static string ExtractDbName(string connString)
    {
        try
        {
            var builder = new SqlConnectionStringBuilder(connString);
            return builder.InitialCatalog;
        }
        catch { return "Database"; }
    }

    private static string BuildMasterConnection(string connString)
    {
        var builder = new SqlConnectionStringBuilder(connString) { InitialCatalog = "master" };
        return builder.ConnectionString;
    }

    private async Task<BackupResultDto> PerformBackupAsync(ProjectDefinition project, bool auto)
    {
        var dir = GetBackupDir(project.ProjectGuid);
        var stamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var prefix = auto ? "auto" : "manual";
        var fileName = $"{prefix}_{project.DatabaseName}_{stamp}.bak";
        var backupPath = Path.Combine(dir, fileName);

        // بکاپ با SQL Server — اتصال به master
        var masterConn = BuildMasterConnection(project.ConnectionString);
        await using var conn = new SqlConnection(masterConn);
        await conn.OpenAsync();
        await conn.ExecuteAsync(
            $"BACKUP DATABASE [{project.DatabaseName}] TO DISK = @path WITH INIT, COMPRESSION",
            new { path = backupPath });

        var info = new FileInfo(backupPath);

        // پاکسازی بکاپ‌های قدیمی (retention)
        if (project.MaxBackupRetention > 0)
        {
            var all = Directory.GetFiles(dir, "*.bak")
                .Select(f => new FileInfo(f))
                .OrderByDescending(f => f.LastWriteTimeUtc)
                .ToList();
            foreach (var old in all.Skip(project.MaxBackupRetention))
            {
                try { old.Delete(); _log.LogInformation("Removed old backup {File}", old.Name); }
                catch (Exception ex) { _log.LogWarning("Could not remove old backup {File}: {Error}", old.Name, ex.Message); }
            }
        }

        return new BackupResultDto
        {
            Success = true,
            FileName = fileName,
            SizeBytes = info.Length,
            DownloadUrl = $"/backup/{project.ProjectGuid}/{fileName}",
            CompletedAtUtc = DateTime.UtcNow
        };
    }
}

/// <summary>درخواست ریستور</summary>
public sealed class RestoreRequestDto
{
    public string BackupFileName { get; set; } = default!;
}