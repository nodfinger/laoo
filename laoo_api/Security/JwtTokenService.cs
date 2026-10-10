using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LaooApi.Models;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace LaooApi.Security;

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
        AddIfValue(claims, "person_id", user.PersonId);
        AddIfValue(claims, "guardian_id", user.GuardianId);
        if (user.UserType == "SCHOOL_STUDENT")
        {
            if (user.StudentId is not > 0 || user.CredentialVersion is not > 0
                || user.CompanyId is not > 0 || user.UserId.HasValue || user.GuardianId.HasValue
                || user.LaooUserId.HasValue || user.PartnerUserId.HasValue || user.PersonId.HasValue
                || user.CanLoginAsUser || user.LoginMode != "SCHOOL_STUDENT" || user.MemberId.HasValue
                || user.ProjectCode is not ("LAOO_SCHOOL" or "LAOO_SCHOOL_FOOD"))
                throw new ArgumentException("Student token requires isolated student identity and credential version.", nameof(user));
            AddIfValue(claims, "student_id", user.StudentId);
            AddIfValue(claims, "credential_version", user.CredentialVersion);
        }
        else if (user.UserType == "BOOKING_MEMBER")
        {
            if (user.MemberId is not > 0 || user.CredentialVersion is not > 0
                || user.CompanyId is not > 0 || user.UserId.HasValue || user.GuardianId.HasValue
                || user.StudentId.HasValue || user.LaooUserId.HasValue || user.PartnerUserId.HasValue
                || user.CanLoginAsUser || user.LoginMode != "BOOKING_MEMBER"
                || user.ProjectCode != "LAOO_BOOKING")
                throw new ArgumentException("Booking member token requires isolated member identity and credential version.", nameof(user));
            AddIfValue(claims, "member_id", user.MemberId);
            AddIfValue(claims, "credential_version", user.CredentialVersion);
        }
        else if (user.StudentId.HasValue || user.MemberId.HasValue || user.CredentialVersion.HasValue)
        {
            throw new ArgumentException("Portal claims cannot be attached to another identity type.", nameof(user));
        }
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
