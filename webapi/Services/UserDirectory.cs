using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WebApi.Services;

public interface IUserDirectory
{
    Task<UserRecord?> FindByUsernameAsync(string username);
}

public sealed class UserRecord
{
    public int UserId { get; set; }
    public string Username { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Role { get; set; } = "User";
    public bool IsActive { get; set; }
}

public sealed class UserDirectory : IUserDirectory
{
    private readonly string? _cs;

    public UserDirectory(IOptions<ConnectionStringsOptions> cs)
    {
        _cs = cs.Value.DefaultConnection;
    }

    public async Task<UserRecord?> FindByUsernameAsync(string username)
    {
        if (string.IsNullOrWhiteSpace(_cs) || string.IsNullOrWhiteSpace(username))
            return null;
        await using var conn = new SqlConnection(_cs);
        return await conn.QueryFirstOrDefaultAsync<UserRecord>(@"
SELECT UserId, Username, PasswordHash, DisplayName, Role, IsActive
FROM [central].[Users]
WHERE Username = @username AND IsDeleted = 0;",
            new { username });
    }
}
