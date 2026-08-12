using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace WebApi.Services;

public sealed class AuthOptions
{
    public string Issuer { get; set; } = "hermes-webapi";
    public string Audience { get; set; } = "hermes-clients";
    public string Key { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 480;
}

public sealed class HermesUser
{
    public int UserId { get; set; }
    public string Username { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Role { get; set; } = "User";
}

public interface IUserTokenService
{
    string Issue(HermesUser user);
    HermesUser? Validate(string? token);
}

public sealed class UserTokenService : IUserTokenService
{
    private readonly AuthOptions _opt;
    private readonly SymmetricSecurityKey _key;

    public UserTokenService(IOptions<AuthOptions> options)
    {
        _opt = options.Value;
        if (string.IsNullOrWhiteSpace(_opt.Key))
            throw new InvalidOperationException(
                "Auth:Key is not configured. A hard-coded fallback key would be a public secret — refuse to start.");
        var raw = _opt.Key;
        _key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(raw.PadRight(32)[..Math.Max(32, raw.Length)]));
    }

    public string Issue(HermesUser user)
    {
        var creds = new SigningCredentials(_key, SecurityAlgorithms.HmacSha256);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new Claim(JwtRegisteredClaimNames.UniqueName, user.Username),
            new Claim(ClaimTypes.Name, user.DisplayName),
            new Claim(ClaimTypes.Role, user.Role)
        };
        var jwt = new JwtSecurityToken(
            issuer: _opt.Issuer,
            audience: _opt.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(Math.Clamp(_opt.AccessTokenMinutes, 15, 24 * 60)),
            signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(jwt);
    }

    public HermesUser? Validate(string? token)
    {
        if (string.IsNullOrWhiteSpace(token))
            return null;
        var handler = new JwtSecurityTokenHandler();
        try
        {
            var principal = handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = _opt.Issuer,
                ValidateAudience = true,
                ValidAudience = _opt.Audience,
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = _key,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromMinutes(1)
            }, out _);

            var id = principal.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
                     ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(id, out var userId))
                return null;
            return new HermesUser
            {
                UserId = userId,
                Username = principal.FindFirst(JwtRegisteredClaimNames.UniqueName)?.Value
                           ?? principal.Identity?.Name
                           ?? "",
                DisplayName = principal.FindFirst(ClaimTypes.Name)?.Value ?? "",
                Role = principal.FindFirst(ClaimTypes.Role)?.Value ?? "User"
            };
        }
        catch
        {
            return null;
        }
    }
}
