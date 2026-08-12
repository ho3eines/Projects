namespace Tarazin.Data;

/// <summary>
/// Loads all named TSQL scripts and serves them by (schema, name).
///
/// Scripts are **embedded resources** in this assembly
/// (<c>Tarazin.Scripts.{schema}.{name}.sql</c>), so both hosts work:
/// the web app and the packaged MAUI app never depend on a content root.
/// A disk-based loader is kept for development/editing workflows.
///
/// Every data operation in the app goes through a named script — pages never
/// contain inline SQL. Schema is the scope guard: each module only calls
/// scripts of its own schema.
/// </summary>
public sealed class ScriptCatalog
{
    private const string EmbeddedPrefix = "Tarazin.Scripts.";

    private readonly Dictionary<string, string> _scripts = new(StringComparer.OrdinalIgnoreCase);

    public ScriptCatalog()
    {
        // Self-loading: both hosts get a ready catalog from DI without any
        // host-specific startup code.
        LoadFromEmbeddedResources(typeof(ScriptCatalog).Assembly);
    }

    /// <summary>Number of scripts loaded (used by the health/status page).</summary>
    public int Count => _scripts.Count;

    /// <summary>Distinct schema names that have at least one script.</summary>
    public IReadOnlyCollection<string> Schemas => _scripts.Keys
        .Select(KeySchema)
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToList();

    /// <summary>
    /// Loads scripts embedded in <paramref name="assembly"/>.
    /// Resource name format: <c>{RootNamespace}.Data.Scripts.{schema}.{name}.sql</c>.
    /// </summary>
    public void LoadFromEmbeddedResources(System.Reflection.Assembly assembly)
    {
        foreach (var resourceName in assembly.GetManifestResourceNames())
        {
            if (!resourceName.StartsWith(EmbeddedPrefix, StringComparison.Ordinal) ||
                !resourceName.EndsWith(".sql", StringComparison.OrdinalIgnoreCase))
                continue;

            var relative = resourceName[EmbeddedPrefix.Length..^4]; // strip prefix + ".sql"
            var dot = relative.LastIndexOf('.');
            if (dot <= 0 || dot == relative.Length - 1)
                continue; // not schema/name shaped

            var schema = relative[..dot];
            var name = relative[(dot + 1)..];
            if (string.IsNullOrWhiteSpace(schema) || string.IsNullOrWhiteSpace(name))
                continue;

            using var stream = assembly.GetManifestResourceStream(resourceName);
            if (stream is null)
                continue;

            using var reader = new StreamReader(stream);
            _scripts[ScriptKey(schema, name)] = reader.ReadToEnd();
        }
    }

    /// <summary>
    /// Loads scripts from a directory (dev convenience): <c>{root}/Data/Scripts/{schema}/{name}.sql</c>.
    /// </summary>
    public void Load(string rootPath)
    {
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
