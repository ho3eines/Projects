namespace Tarazin.Data;

/// <summary>
/// Splits a TSQL script into batches on the <c>GO</c> batch separator.
///
/// <c>GO</c> is a client-tool directive (SSMS / sqlcmd), NOT valid TSQL — so a
/// script containing <c>GO</c> lines cannot be sent to <see cref="Microsoft.Data.SqlClient.SqlCommand"/>
/// as a single command; SQL Server rejects it with «Incorrect syntax near 'GO'».
/// Scripts authored in SSMS style (e.g. <c>accounting/_Ensure.sql</c>) use
/// <c>GO</c> to force batch boundaries (CREATE INDEX and similar statements
/// must be the first statement in their batch). This helper splits such
/// scripts so each batch can be executed separately.
/// </summary>
public static class SqlScript
{
    /// <summary>
    /// Splits <paramref name="sql"/> on standalone <c>GO</c> lines and returns
    /// the non-empty batches in order. Lines such as <c>GO 2</c> (repeat count)
    /// are also recognized as separators.
    /// </summary>
    public static IReadOnlyList<string> SplitBatches(string sql)
    {
        var batches = new List<string>();
        var current = new System.Text.StringBuilder();

        foreach (var line in sql.Replace("\r\n", "\n").Split('\n'))
        {
            if (IsSeparator(line))
            {
                AddBatch(batches, current);
                continue;
            }

            current.AppendLine(line);
        }

        AddBatch(batches, current);
        return batches;
    }

    private static bool IsSeparator(string line)
    {
        var trimmed = line.Trim();
        if (trimmed.Equals("GO", StringComparison.OrdinalIgnoreCase))
            return true;

        // «GO n» — batch separator with a repeat count (rare, but valid in sqlcmd).
        if (trimmed.Length > 2 &&
            trimmed.StartsWith("GO", StringComparison.OrdinalIgnoreCase) &&
            char.IsWhiteSpace(trimmed[2]))
        {
            return int.TryParse(trimmed[2..].Trim(), out _);
        }

        return false;
    }

    private static void AddBatch(List<string> batches, System.Text.StringBuilder current)
    {
        var batch = current.ToString().Trim();
        if (batch.Length > 0)
            batches.Add(batch);
        current.Clear();
    }
}
