using Microsoft.Data.SqlClient;
using Dapper;
using WebApi.Models;

namespace WebApi.Services;

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
                   AutoBackupEnabled, IsActive
            FROM dbo.Projects
            ORDER BY Name");
        return list.ToList();
    }

    public async Task<int> CreateAsync(ProjectCreateDto dto)
    {
        var connStr = _config.GetConnectionString("DefaultConnection")!;
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        var sql = @"
INSERT INTO dbo.Projects (
    Name, ProjectGuid, LoginTokenHash, EncryptionKey, ApiKey,
    SessionTimeoutMinutes, IsActive, ConnectionString, DatabaseName,
    DatabaseProvider, AutoBackupEnabled, AutoBackupIntervalMinutes,
    AutoBackupTimeUtc, MaxBackupRetention, Description, CreatedAtUtc
)
VALUES (
    @Name, NEWID(), NEWID(), NEWID(), @ApiKey,
    @SessionTimeoutMinutes, @IsActive, @ConnectionString, @DatabaseName,
    'SqlServer', @AutoBackupEnabled, @AutoBackupIntervalMinutes,
    @AutoBackupTimeUtc, @MaxBackupRetention, @Description, GETUTCDATE()
)";
        return await conn.ExecuteAsync(sql, new
        {
            dto.Name,
            dto.ApiKey,
            dto.SessionTimeoutMinutes,
            dto.IsActive,
            dto.ConnectionString,
            dto.DatabaseName,
            dto.AutoBackupEnabled,
            dto.AutoBackupIntervalMinutes,
            dto.AutoBackupTimeUtc,
            dto.MaxBackupRetention,
            dto.Description
        });
    }

    public async Task<int> UpdateAsync(ProjectRow project)
    {
        var connStr = _config.GetConnectionString("DefaultConnection")!;
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        var sql = @"
UPDATE dbo.Projects
SET Name = @Name,
    ApiKey = @ApiKey,
    SessionTimeoutMinutes = @SessionTimeoutMinutes,
    IsActive = @IsActive,
    ConnectionString = @ConnectionString,
    DatabaseName = @DatabaseName,
    AutoBackupEnabled = @AutoBackupEnabled
WHERE ProjectGuid = @ProjectGuid";

        return await conn.ExecuteAsync(sql, new
        {
            project.Name,
            project.ApiKey,
            project.SessionTimeoutMinutes,
            project.IsActive,
            project.ConnectionString,
            project.DatabaseName,
            project.AutoBackupEnabled,
            project.ProjectGuid
        });
    }

    public async Task<int> DeleteAsync(Guid projectGuid)
    {
        var connStr = _config.GetConnectionString("DefaultConnection")!;
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        var sql = "DELETE FROM dbo.Projects WHERE ProjectGuid = @ProjectGuid";
        return await conn.ExecuteAsync(sql, new { ProjectGuid = projectGuid });
    }
}