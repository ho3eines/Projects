namespace TarazinApp.Services;

/// <summary>
/// Loads all named TSQL scripts from <c>Data/Scripts/{schema}/{name}.sql</c>
/// once at startup and serves them by (schema, name).
///
/// Every data operation in the app goes through a named script — pages never
/// contain inline SQL. This keeps the reports-first design and the per-schema
/// boundaries that the old webapi enforced, but now everything runs in the
/// same Blazor Server process (no HTTP round-trip, no webapi).
/// </summary>
public sealed class ScriptCatalog
{
    private readonly Dictionary<string, string> _scripts = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Number of scripts loaded (used by the health/status page).</summary>
    public int Count => _scripts.Count;

    /// <summary>Distinct schema names that have at least one script.</summary>
    public IReadOnlyCollection<string> Schemas => _scripts.Keys
        .Select(KeySchema)
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToList();

    public void Load(string rootPath)
    {
        _scripts.Clear();

        var scriptsRoot = Path.Combine(rootPath, "Data", "Scripts");
        if (!Directory.Exists(scriptsRoot))
            return;

        foreach (var file in Directory.EnumerateFiles(scriptsRoot, "*.sql", SearchOption.AllDirectories))
        {
            var schema = Path.GetFileName(Path.GetDirectoryName(file) ?? string.Empty);
            var name = Path.GetFileNameWithoutExtension(file);
            if (string.IsNullOrWhiteSpace(schema) || string.IsNullOrWhiteSpace(name))
                continue;

            _scripts[ScriptKey(schema, name)] = File.ReadAllText(file);
        }
    }

    public bool TryGet(string schema, string scriptName, out string sql)
        => _scripts.TryGetValue(ScriptKey(schema, scriptName), out sql!);

    /// <summary>Stable dictionary key for a (schema, name) pair.</summary>
    public static string ScriptKey(string schema, string scriptName)
        => $"{schema.Trim().ToLowerInvariant()}/{scriptName.Trim().ToLowerInvariant()}";

    private static string KeySchema(string key)
        => key[..key.IndexOf('/')];
}
