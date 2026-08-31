namespace Tarazin.Services;

/// <summary>تعریف یک گزارش قابل چاپ (کاتالوگ) — بدون وابستگی به موتور چاپ خاص.</summary>
public sealed record BiReportDefinition(
    string Key,
    string Title,
    string? Subtitle,
    string Schema,
    string Script,
    Dictionary<string, object?> Params,
    IReadOnlyDictionary<string, string>? ColumnTitles);
