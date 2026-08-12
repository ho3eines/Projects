using System;
using System.IO;
using System.Text.Json.Serialization;

namespace WebApi.Models;

/// <summary>
/// اطلاعات کامل یک پروژه در webapi
/// شامل کانکشن استرینگ دیتابیس اختصاصی، تنظیمات بکاپ، و متادیتا
/// </summary>
public sealed class ProjectDefinition
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    
    // === Auth & Security ===
    public string LoginTokenHash { get; set; } = default!;
    public string EncryptionKey { get; set; } = default!;
    public string ApiKey { get; set; } = default!;
    
    // === Session ===
    public int SessionTimeoutMinutes { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    
    // === Database (اختصاصی هر پروژه) ===
    /// <summary>Connection string کامل دیتابیس این پروژه</summary>
    public string ConnectionString { get; set; } = default!;
    
    /// <summary>نام دیتابیس (برای نمایش و بکاپ)</summary>
    public string DatabaseName { get; set; } = default!;
    
    /// <summary>نوع دیتابیس (SqlServer, PostgreSQL, ...)</summary>
    public string DatabaseProvider { get; set; } = "SqlServer";
    
    // === Backup Settings ===
    /// <summary>آیا بکاپ خودکار فعال است</summary>
    public bool AutoBackupEnabled { get; set; } = false;
    
    /// <summary>دوره بکاپ خودکار (به دقیقه) - پیش‌فرض روزانه 1440</summary>
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    
    /// <summary>ساعت بکاپ روزانه (UTC) - برای بکاپ‌های روزانه</summary>
    public TimeSpan? AutoBackupTimeUtc { get; set; } = new TimeSpan(2, 0, 0); // 02:00 UTC
    
    /// <summary>تعداد بکاپ‌های نگهداری شده (باقی حذف می‌شوند)</summary>
    public int MaxBackupRetention { get; set; } = 7;
    
    /// <summary>مسیر نسبی بکاپ‌ها در wwwroot (پیش‌فرض: backup/{ProjectGuid})</summary>
    public string BackupRelativePath { get; set; } = string.Empty; // ست می‌شود در کنترلر
    
    // === Metadata ===
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? LastBackupAtUtc { get; set; }
    public string? Description { get; set; }
    public string? Icon { get; set; }
    
    // === Computed ===
    [JsonIgnore]
    public string BackupFullPath => string.IsNullOrEmpty(BackupRelativePath) 
        ? Path.Combine("wwwroot", "backup", ProjectGuid.ToString()) 
        : Path.Combine("wwwroot", BackupRelativePath);
}

/// <summary>DTO برای ایجاد/ویرایش پروژه</summary>
public sealed class CreateProjectDto
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public string LoginTokenHash { get; set; } = default!;
    public string EncryptionKey { get; set; } = default!;
    public string ApiKey { get; set; } = default!;
    public int SessionTimeoutMinutes { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    
    // Database
    public string ConnectionString { get; set; } = default!;
    public string DatabaseName { get; set; } = default!;
    public string DatabaseProvider { get; set; } = "SqlServer";
    
    // Backup
    public bool AutoBackupEnabled { get; set; } = false;
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    public TimeSpan? AutoBackupTimeUtc { get; set; } = new TimeSpan(2, 0, 0);
    public int MaxBackupRetention { get; set; } = 7;
    
    public string? Description { get; set; }
    public string? Icon { get; set; }
}

/// <summary>DTO برای آپدیت تنظیمات بکاپ</summary>
public sealed class UpdateBackupSettingsDto
{
    public bool AutoBackupEnabled { get; set; }
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    public TimeSpan? AutoBackupTimeUtc { get; set; }
    public int MaxBackupRetention { get; set; } = 7;
}

/// <summary>DTO اطلاعات بکاپ</summary>
public sealed class BackupInfoDto
{
    public string FileName { get; set; } = default!;
    public long SizeBytes { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public string DownloadUrl { get; set; } = default!;
    public bool IsAutoBackup { get; set; }
}

/// <summary>DTO پاسخ عملیات بکاپ</summary>
public sealed class BackupResultDto
{
    public bool Success { get; set; }
    public string? FileName { get; set; }
    public long? SizeBytes { get; set; }
    public string? DownloadUrl { get; set; }
    public string? Error { get; set; }
    public DateTime CompletedAtUtc { get; set; } = DateTime.UtcNow;
}

/// <summary>DTO برای نمایش در UI</summary>
public sealed class ProjectDefinitionDto
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public string LoginTokenHash { get; set; } = default!;
    public string EncryptionKey { get; set; } = default!;
    public string ApiKey { get; set; } = default!;
    public int SessionTimeoutMinutes { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    public string ConnectionString { get; set; } = default!;
    public string DatabaseName { get; set; } = default!;
    public string DatabaseProvider { get; set; } = "SqlServer";
    public bool AutoBackupEnabled { get; set; }
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    public TimeSpan? AutoBackupTimeUtc { get; set; }
    public int MaxBackupRetention { get; set; } = 7;
    public DateTime? LastBackupAtUtc { get; set; }
    public string? Description { get; set; }
    public string? Icon { get; set; }
}

/// <summary>DTO برای ایجاد/ویرایش از UI</summary>
public sealed class ProjectEditDto
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public string LoginTokenHash { get; set; } = default!;
    public string EncryptionKey { get; set; } = default!;
    public string ApiKey { get; set; } = string.Empty;
    public int SessionTimeoutMinutes { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    public string ConnectionString { get; set; } = default!;
    public string DatabaseName { get; set; } = default!;
    public string DatabaseProvider { get; set; } = "SqlServer";
    public bool AutoBackupEnabled { get; set; }
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    public TimeSpan? AutoBackupTimeUtc { get; set; } = new TimeSpan(2, 0, 0);
    public int MaxBackupRetention { get; set; } = 7;
    public string? Description { get; set; }
    public string? Icon { get; set; }
}

/// <summary>پاسخ لیست پروژه‌ها</summary>
public sealed class ProjectListResponse
{
    public List<ProjectDefinitionDto> Projects { get; set; } = new();
}

/// <summary>پاسخ لیست بکاپ‌ها</summary>
public sealed class BackupListResponse
{
    public int Total { get; set; }
    public List<BackupInfoDto> Backups { get; set; } = new();
}