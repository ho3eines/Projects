using Microsoft.Extensions.Options;

namespace WebApi.Services;

public sealed class HermesProject
{
    public Guid Guid { get; set; }
    public string Name { get; set; } = "";
    public string Schema { get; set; } = "";
    public string SharedKey { get; set; } = "";
    public bool IsActive { get; set; } = true;
}

public sealed class HermesProjectsOptions
{
    public List<HermesProject> Projects { get; set; } = new();
    public int HandshakeWindowSeconds { get; set; } = 90;
    public int SessionMinutes { get; set; } = 15;
}

public interface IProjectCatalog
{
    HermesProject? Find(Guid projectGuid);
    IReadOnlyList<HermesProject> AllActive();
}

public sealed class ProjectCatalog : IProjectCatalog
{
    private readonly IReadOnlyDictionary<Guid, HermesProject> _byGuid;

    public ProjectCatalog(IOptions<HermesProjectsOptions> options)
    {
        _byGuid = options.Value.Projects
            .Where(p => p.Guid != Guid.Empty && !string.IsNullOrWhiteSpace(p.Schema))
            .ToDictionary(p => p.Guid, p => p);
    }

    public HermesProject? Find(Guid projectGuid)
        => _byGuid.TryGetValue(projectGuid, out var p) ? p : null;

    public IReadOnlyList<HermesProject> AllActive()
        => _byGuid.Values.Where(p => p.IsActive).ToList();
}
