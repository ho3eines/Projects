using Microsoft.Data.SqlClient;
using Dapper;
using WebApi.Models;

namespace WebApi.Services;

/// <summary>
/// Read-only project list for the Blazor Server admin UI (Projects.razor).
/// Create/update/delete are performed by ProjectController (the /api/projects
/// REST surface); this service only serves the admin dashboard list.
/// </summary>
public class ProjectService
{
    private readonly IConfiguration _config;

    public ProjectService(IConfiguration config)
    {
        _config = config;
    }

    public async Task<List<ProjectRow>> GetAllAsync()
    {
        var connStr = _config.GetConnectionString("DefaultConnection")!;
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();
        var list = await conn.QueryAsync<ProjectRow>(@"
            SELECT Name, ProjectGuid, ApiKey, SessionTimeoutMinutes,
                   AutoBackupEnabled, IsActive, [Schema], Icon, Description, ClientUrl
            FROM dbo.Projects
            ORDER BY Name");
        return list.ToList();
    }
}
