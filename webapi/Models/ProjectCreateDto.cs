using System;

namespace WebApi.Models;

public class ProjectCreateDto
{
    public string Name { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public int SessionTimeoutMinutes { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    public string ConnectionString { get; set; } = "";
    public string DatabaseName { get; set; } = "";
    public bool AutoBackupEnabled { get; set; } = true;
    public int AutoBackupIntervalMinutes { get; set; } = 1440;
    public TimeSpan AutoBackupTimeUtc { get; set; } = new TimeSpan(2, 0, 0);
    public int MaxBackupRetention { get; set; } = 7;
    public string? Description { get; set; }
    public string ClientUrl { get; set; } = "";
}