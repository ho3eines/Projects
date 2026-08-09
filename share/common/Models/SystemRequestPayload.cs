using System.Text.Json;

namespace Share.Models;

/// <summary>
/// The single request payload used by ALL projects.
/// Sent to POST /api/system/{query|execute|scalar}
/// </summary>
public class SystemRequestPayload
{
    /// <summary>Named TSQL file, e.g. "DailyDocuments" or "accounting/DailyDocuments"</summary>
    public string ScriptName { get; set; } = "";

    /// <summary>JSON parameters passed to the TSQL script</summary>
    public JsonElement? Parameters { get; set; }

    /// <summary>Unique request id for tracing</summary>
    public string RequestId { get; set; } = Guid.NewGuid().ToString();

    /// <summary>Optional database schema (project name)</summary>
    public string? Schema { get; set; }
}

public class SystemQueryResult<T>
{
    public List<T> Data { get; set; } = new();
    public int TotalCount { get; set; }
    public string? RequestId { get; set; }
}

public class SystemExecuteResult
{
    public int AffectedRows { get; set; }
    public string? RequestId { get; set; }
}

public class SystemScalarResult<T>
{
    public T? Value { get; set; }
    public string? RequestId { get; set; }
}