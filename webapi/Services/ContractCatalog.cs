using System.Text.Json;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public interface IContractCatalog
{
    JsonElement Root { get; }
}

/// <summary>
/// Contract registry (PRD §3, ADR-003): serves webapi/Data/contracts.manifest.json
/// at GET /api/contracts. Loaded once at startup.
/// </summary>
public sealed class ContractCatalog : IContractCatalog
{
    public JsonElement Root { get; }

    public ContractCatalog(IWebHostEnvironment env, ILogger<ContractCatalog> logger)
    {
        var path = Path.Combine(env.ContentRootPath, "Data", "contracts.manifest.json");
        if (!File.Exists(path))
        {
            logger.LogWarning("contracts.manifest.json not found at {Path}", path);
            using var empty = JsonDocument.Parse("{\"contracts\":[]}");
            Root = empty.RootElement.Clone();
            return;
        }

        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        Root = doc.RootElement.Clone();
    }
}
