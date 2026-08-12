using System;
using System.Text.Json.Serialization;

namespace BlazorDeployService.Models;

// ===================== AUTH =====================

/// <summary>درخواست ورود — projectGuid + loginToken (انکریپت‌شده) برای دریافت SessionToken</summary>
public sealed class LoginRequest
{
    /// <summary>شناسه پروژه (project-guid)</summary>
    public Guid ProjectGuid { get; set; }

    /// <summary>توکن ورود ادمین (در webapi تعریف می‌شود) — انکریپت‌شده ارسال می‌شود</summary>
    public string LoginToken { get; set; } = default!;

    /// <summary>نسخه پکیج کلاینت برای اطلاع سرور</summary>
    public string ClientVersion { get; set; } = "1.0.100";
}

/// <summary>پاسخ ورود موفق</summary>
public sealed class LoginResponse
{
    /// <summary>توکن نشست — در همه درخواست‌های بعدی به‌عنوان X-Auth-Token فرستاده می‌شود</summary>
    public string SessionToken { get; set; } = default!;

    /// <summary>انقضای نشست به‌ثانیه (پیش‌فرض 600 = 10 دقیقه)</summary>
    public int ExpiresInSeconds { get; set; } = 600;

    /// <summary>اطلاعات پروژه از سرور</summary>
    public ProjectInfo Project { get; set; } = new();
}

/// <summary>اطلاعات پروژه که پس از لاگین از سرور می‌آید</summary>
public sealed class ProjectInfo
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public string? Icon { get; set; }
    public int SessionTimeoutSeconds { get; set; } = 600;
}

// ===================== SESSION =====================

/// <summary>وضعیت نشست در کلاینت — برای UI و تایمر بیکاری</summary>
public enum SessionStatus
{
    None,
    LoggingIn,
    Active,
    Expired,
    Rejected
}

/// <summary>رویداد منقضی شدن نشست — UI باید صفحه لاگین باز کند</summary>
public sealed class SessionExpiredEventArgs : EventArgs
{
    public string Reason { get; init; } = default!;
    public DateTime ExpiredAtUtc { get; init; } = DateTime.UtcNow;
}

// ===================== PROJECT REGISTRY (سرور) =====================

/// <summary>تعریف یک پروژه در webapi — جدول Projects</summary>
public sealed class ProjectDefinition
{
    public Guid ProjectGuid { get; set; }
    public string Name { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public string LoginTokenHash { get; set; } = default!;
    public string EncryptionKey { get; set; } = default!;
    public string ApiKey { get; set; } = default!;
    public int SessionTimeoutSeconds { get; set; } = 600;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAtUtc { get; set; }
    public string? Description { get; set; }
}

/// <summary>نشست فعال در سرور (حافظه/کش)</summary>
public sealed class ServerSession
{
    public string SessionToken { get; set; } = default!;
    public Guid ProjectGuid { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime LastActivityUtc { get; set; }
    public int TimeoutSeconds { get; set; } = 600;
    public string ClientVersion { get; set; } = string.Empty;

    public bool IsExpired => (DateTime.UtcNow - LastActivityUtc).TotalSeconds > TimeoutSeconds;
    public void Touch() => LastActivityUtc = DateTime.UtcNow;
}