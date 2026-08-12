namespace WebApi.Models;

public class ProjectRow
{
    public string Name { get; set; } = "";
    public string Schema { get; set; } = "";
    public Guid ProjectGuid { get; set; }
    public string ApiKey { get; set; } = "";
    public int SessionTimeoutMinutes { get; set; }
    public bool AutoBackupEnabled { get; set; }
    public bool IsActive { get; set; }
    public string ConnectionString { get; set; } = "";
    public string DatabaseName { get; set; } = "";
    public string? Description { get; set; }
    public string? Icon { get; set; }
    /// <summary>آدرس کلاینت پروژه — لینک ورود به اپ WASM</summary>
    public string ClientUrl { get; set; } = "";
}