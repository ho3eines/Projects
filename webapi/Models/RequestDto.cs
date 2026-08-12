using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace WebApi.Models;

/// <summary>توضیحات یک ستون برای ساخت خودکار جدول — ارسال‌شده از کلاینت</summary>
public sealed class SchemaColumnInfoDto
{
    public string Name { get; set; } = default!;
    public string SqlType { get; set; } = "nvarchar(max)";
    [JsonPropertyName("isPrimaryKey")] public bool IsPrimaryKey { get; set; }
    [JsonPropertyName("isIdentity")] public bool IsIdentity { get; set; }
    [JsonPropertyName("isRequired")] public bool IsRequired { get; set; }
    [JsonPropertyName("defaultExpression")] public string? DefaultExpression { get; set; }
}

/// <summary>متادیتای مدل از کلاینت — سرور بدون داشتن کلاس مدل، جدول/ستون می‌سازد</summary>
public sealed class ModelSchemaInfoDto
{
    public string TypeName { get; set; } = default!;
    public string Schema { get; set; } = "dbo";
    public string Table { get; set; } = default!;
    public int TableVersion { get; set; }
    public List<SchemaColumnInfoDto> Columns { get; set; } = new();
}

/// <summary>پیلود استاندارد همه درخواست‌ها</summary>
public sealed class DeployRequestPayloadDto
{
    /// <summary>
    /// Nullable on purpose: named-script calls send only <see cref="ScriptName"/>.
    /// Do NOT make this non-nullable — with [ApiController] + Nullable enable,
    /// ASP.NET Core implicitly adds [Required] to non-nullable reference-type
    /// properties, which rejects the request during model binding (before the
    /// action runs) with "The Tsql field is required."
    /// </summary>
    public string? Tsql { get; set; }
    public ModelSchemaInfoDto? Model { get; set; }
    public Dictionary<string, object?>? Parameters { get; set; }
    public string? ScriptName { get; set; }
    public string? EncryptedPayload { get; set; }
    public Guid CorrelationId { get; set; } = Guid.NewGuid();
    public Guid ProjectGuid { get; set; }
    public Guid? UserId { get; set; }
    [JsonPropertyName("requireUser")] public bool RequireUser { get; set; }
}

/// <summary>پاسخ استاندارد — کپی از شکل پاسخ کلاینت</summary>
public sealed class DeployResponseDto
{
    public Guid? CorrelationId { get; set; }
    public int TotalCount { get; set; }
    public object? Data { get; set; }
    public int AffectedRows { get; set; }
    public long DurationMs { get; set; }
    public string? Error { get; set; }
}