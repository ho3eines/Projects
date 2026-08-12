using System.Text.Json;

namespace Hermes.ContractTests;

public sealed record ContractDef(
    string Name,
    int Version,
    string Owner,
    string? SearchScript,
    string? LegacySearchScript,
    IReadOnlyList<string> Fields,
    IReadOnlyDictionary<string, object?> SampleParams);

public static class ContractManifest
{
    public static List<ContractDef> Load(string repoRoot)
    {
        var path = Path.Combine(repoRoot, "webapi", "Data", "contracts.manifest.json");
        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        var root = doc.RootElement;
        var list = new List<ContractDef>();

        if (!root.TryGetProperty("contracts", out var contracts))
            return list;

        foreach (var c in contracts.EnumerateArray())
        {
            var name = c.GetProperty("name").GetString() ?? "";
            var version = c.TryGetProperty("version", out var v) ? v.GetInt32() : 1;
            var owner = c.GetProperty("owner").GetString() ?? "";

            string? search = null;
            if (c.TryGetProperty("scripts", out var scripts) && scripts.TryGetProperty("search", out var s) && s.ValueKind == JsonValueKind.String)
                search = s.GetString();

            string? legacy = null;
            if (c.TryGetProperty("legacyScripts", out var legacyScripts) && legacyScripts.TryGetProperty("search", out var ls) && ls.ValueKind == JsonValueKind.String)
                legacy = ls.GetString();

            var fields = new List<string>();
            if (c.TryGetProperty("fields", out var fieldsEl))
            {
                foreach (var f in fieldsEl.EnumerateArray())
                    fields.Add(f.GetProperty("name").GetString() ?? "");
            }

            var sampleParams = new Dictionary<string, object?>();
            if (c.TryGetProperty("sampleParams", out var sp) && sp.ValueKind == JsonValueKind.Object)
            {
                foreach (var p in sp.EnumerateObject())
                    sampleParams[p.Name] = p.Value.Clone();
            }

            list.Add(new ContractDef(name, version, owner, search, legacy, fields, sampleParams));
        }

        return list;
    }
}
