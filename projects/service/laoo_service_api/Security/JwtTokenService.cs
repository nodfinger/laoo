using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LaooServiceApi.Models;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace LaooServiceApi.Security;

public sealed class JwtTokenService
{
    private readonly JwtOptions _options;

    public JwtTokenService(IOptions<JwtOptions> options)
    {
        _options = options.Value;
    }

    public TokenResult CreateToken(AuthenticatedUser user)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddMinutes(_options.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.SubjectId),
            new(JwtRegisteredClaimNames.UniqueName, user.Username),
            new("display_name", user.DisplayName),
            new("user_type", user.UserType),
            new("login_mode", user.LoginMode),
            new("project_id", user.ProjectId.ToString()),
            new("project_code", user.ProjectCode)
        };

        AddIfValue(claims, "laoo_user_id", user.LaooUserId);
        AddIfValue(claims, "partner_user_id", user.PartnerUserId);
        AddIfValue(claims, "partner_id", user.PartnerId);
        AddIfValue(claims, "user_id", user.UserId);
        AddIfValue(claims, "company_id", user.CompanyId);
        AddIfValue(claims, "branch_id", user.BranchId);

        if (user.CanLoginAsUser)
        {
            claims.Add(new Claim("can_login_as_user", "true"));
        }

        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_options.SecretKey));

        var credentials = new SigningCredentials(
            key,
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            notBefore: now,
            expires: expiresAt,
            signingCredentials: credentials);

        return new TokenResult(
            new JwtSecurityTokenHandler().WriteToken(token),
            expiresAt);
    }

    private static void AddIfValue(
        ICollection<Claim> claims,
        string claimType,
        long? value)
    {
        if (value.HasValue)
        {
            claims.Add(new Claim(claimType, value.Value.ToString()));
        }
    }
}
