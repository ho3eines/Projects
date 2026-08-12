using Xunit;
using Xunit.SkippableFact;

namespace Hermes.ContractTests;

/// <summary>
/// PRD AC #1/#4 + ADR-003: every shared contract's search script must return
/// exactly the columns declared in contracts.manifest.json (the DTO shape).
/// Any rename/removal fails the build.
/// </summary>
public class ContractShapeTests : IClassFixture<TestDatabase>
{
    private readonly TestDatabase _db;
    private static readonly List<ContractDef> Contracts = ContractManifest.Load(
        Environment.GetEnvironmentVariable("HERMES_REPO_ROOT") ?? FindRepoRoot());

    public ContractShapeTests(TestDatabase db) => _db = db;

    private const string SkipMsg = "SQL Server not reachable — set HERMES_TEST_CONNECTION or run `docker compose up`";

    [SkippableFact]
    public void Database_is_reachable()
        => Skip.IfNot(_db.Available, SkipMsg);

    [SkippableTheory]
    [MemberData(nameof(AllContracts))]
    public async Task Search_script_shape_matches_manifest(ContractDef contract)
    {
        Skip.IfNot(_db.Available, SkipMsg);
        Assert.False(string.IsNullOrWhiteSpace(contract.SearchScript), $"{contract.Name}: no search script in manifest");

        var sql = await _db.ReadScriptAsync(contract.Owner, contract.SearchScript!);
        var columns = await _db.Sql.QueryColumnsAsync(sql, contract.SampleParams);

        var expected = contract.Fields.OrderBy(f => f, StringComparer.OrdinalIgnoreCase).ToList();
        var actual = columns.OrderBy(c => c, StringComparer.OrdinalIgnoreCase).ToList();

        Assert.True(expected.SequenceEqual(actual, StringComparer.OrdinalIgnoreCase),
            $"{contract.Name} v{contract.Version}: expected columns [{string.Join(", ", expected)}] but got [{string.Join(", ", actual)}]");
    }

    [SkippableFact]
    public async Task Party_v1_script_is_backward_compatible()
    {
        Skip.IfNot(_db.Available, SkipMsg);
        var party = Contracts.First(c => c.Name == "Party");
        Assert.False(string.IsNullOrWhiteSpace(party.LegacySearchScript), "Party v1 script not declared in manifest");

        var sql = await _db.ReadScriptAsync(party.Owner, party.LegacySearchScript!);
        var columns = await _db.Sql.QueryColumnsAsync(sql, party.SampleParams);

        // v1 = v2 fields minus NationalId (the only v2 addition).
        var v1Expected = party.Fields.Where(f => !f.Equals("NationalId", StringComparison.OrdinalIgnoreCase))
            .OrderBy(f => f, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var actual = columns.OrderBy(c => c, StringComparer.OrdinalIgnoreCase).ToList();

        Assert.True(v1Expected.SequenceEqual(actual, StringComparer.OrdinalIgnoreCase),
            $"Party v1: expected [{string.Join(", ", v1Expected)}] but got [{string.Join(", ", actual)}]");
    }

    public static IEnumerable<object[]> AllContracts()
        => Contracts.Select(c => new object[] { c });

    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "webapi", "Data", "contracts.manifest.json")))
                return dir.FullName;
            dir = dir.Parent;
        }
        throw new InvalidOperationException("Repository root not found — set HERMES_REPO_ROOT");
    }
}
