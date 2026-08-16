using System.Data;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Laoo.Api.Models.Auth;
using LaooApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Laoo.Api.Controllers;

[ApiController]
[Route("api/auth")]
[Authorize]
public sealed class AuthContextController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthContextController> _logger;

    public AuthContextController(
        IConfiguration configuration,
        ILogger<AuthContextController> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    [HttpGet("post-login-context")]
    [ProducesResponseType(typeof(PostLoginContextResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PostLoginContextResponse>> GetPostLoginContext(
        CancellationToken cancellationToken)
    {
        if (!TryResolveTokenIdentity(out var identity))
        {
            return Unauthorized(new { message = "Token identity is invalid." });
        }

        var connectionString = _configuration.GetConnectionString("LaooDatabase");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            _logger.LogError("Connection string 'LaooDatabase' is not configured.");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "Authentication database connection is not configured." });
        }

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        return identity.UserType switch
        {
            AuthUserTypes.LaooSupport => await BuildLaooContextAsync(
                connection, identity.SubjectId, identity.ProjectId, cancellationToken),
            AuthUserTypes.PartnerUser => await BuildPartnerContextAsync(
                connection, identity.SubjectId, identity.ProjectId, cancellationToken),
            AuthUserTypes.CompanyUser => await BuildCompanyContextAsync(
                connection, identity.SubjectId, identity.ProjectId, cancellationToken),
            _ => Unauthorized(new { message = "Token identity is invalid." })
        };
    }

    private async Task<ActionResult<PostLoginContextResponse>> BuildLaooContextAsync(
        SqlConnection connection,
        long laooUserId,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT u.LaooUserID, u.Username, u.DisplayName, u.IsSupportUser,
                   CAST(CASE WHEN u.CanLoginAsUser = 1 AND up.CanLoginAsUser = 1
                             THEN 1 ELSE 0 END AS bit) AS CanLoginAsUser
            FROM dbo.TDADLaooUser AS u
            INNER JOIN dbo.TDADLaooUserProject AS up
                ON up.LaooUserID = u.LaooUserID
               AND up.ProjectID = @ProjectID
               AND up.IsActive = 1
               AND up.CanAccess = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = up.ProjectID
               AND project.IsActive = 1
            WHERE u.LaooUserID = @UserID
              AND u.IsSupportUser = 1
              AND u.IsActive = 1;
            """;

        await using var command = CreateIdentityCommand(
            sql, connection, laooUserId, projectId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return IdentityNotFound();

        var response = new PostLoginContextResponse
        {
            UserType = AuthUserTypes.LaooSupport,
            UserId = reader.GetInt64(0),
            Username = reader.GetString(1),
            DisplayName = reader.GetString(2),
            IsSupportUser = reader.GetBoolean(3),
            CanLoginAsUser = reader.GetBoolean(4)
        };
        await reader.DisposeAsync();
        response.Projects.AddRange(await LoadLaooProjectAsync(
            connection, laooUserId, projectId, cancellationToken));
        return Ok(response);
    }

    private async Task<ActionResult<PostLoginContextResponse>> BuildPartnerContextAsync(
        SqlConnection connection,
        long partnerUserId,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT u.PartnerUserID, u.PartnerID, u.Username, u.DisplayName
            FROM dbo.TDADPartnerUser AS u
            INNER JOIN dbo.TDADPartner AS partner
                ON partner.PartnerID = u.PartnerID
               AND partner.IsActive = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            WHERE u.PartnerUserID = @UserID
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.PartnerSql}};
            """;

        await using var command = CreateIdentityCommand(
            sql, connection, partnerUserId, projectId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return IdentityNotFound();

        var partnerId = reader.GetInt64(1);
        var response = new PostLoginContextResponse
        {
            UserType = AuthUserTypes.PartnerUser,
            UserId = reader.GetInt64(0),
            PartnerId = partnerId,
            Username = reader.GetString(2),
            DisplayName = reader.GetString(3),
            IsSupportUser = false,
            CanLoginAsUser = false
        };
        await reader.DisposeAsync();
        response.Companies.AddRange(await LoadPartnerCompaniesAsync(
            connection, partnerUserId, partnerId, projectId, cancellationToken));
        return Ok(response);
    }

    private async Task<ActionResult<PostLoginContextResponse>> BuildCompanyContextAsync(
        SqlConnection connection,
        long userId,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT u.UserID, u.Username, u.DisplayName, u.CompanyID
            FROM dbo.TDADUser AS u
            INNER JOIN dbo.TDADCompany AS company
                ON company.CompanyID = u.CompanyID
               AND company.IsActive = 1
            INNER JOIN dbo.TDADPartner AS partner
                ON partner.PartnerID = company.PartnerID
               AND partner.IsActive = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            WHERE u.UserID = @UserID
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.CompanySql}};
            """;

        await using var command = CreateIdentityCommand(sql, connection, userId, projectId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) return IdentityNotFound();

        var companyId = reader.GetInt64(3);
        var response = new PostLoginContextResponse
        {
            UserType = AuthUserTypes.CompanyUser,
            UserId = reader.GetInt64(0),
            Username = reader.GetString(1),
            DisplayName = reader.GetString(2),
            IsSupportUser = false,
            CanLoginAsUser = false
        };
        await reader.DisposeAsync();

        response.Companies.AddRange(await LoadUserCompaniesAsync(
            connection, userId, companyId, projectId, cancellationToken));
        response.Branches.AddRange(await LoadUserBranchesAsync(
            connection, userId, companyId, projectId, cancellationToken));
        response.Projects.AddRange(await LoadUserProjectAsync(
            connection, userId, companyId, projectId, cancellationToken));
        return Ok(response);
    }

    private static async Task<List<AuthProjectItem>> LoadLaooProjectAsync(
        SqlConnection connection,
        long userId,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT project.ProjectID, project.ProjectCode, project.ProjectNameTH,
                   project.ProjectNameEN, userProject.CanAccess,
                   userProject.CanLoginAsUser
            FROM dbo.TDADLaooUserProject AS userProject
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = userProject.ProjectID
               AND project.IsActive = 1
            WHERE userProject.LaooUserID = @UserID
              AND userProject.ProjectID = @ProjectID
              AND userProject.IsActive = 1
              AND userProject.CanAccess = 1;
            """;

        await using var command = CreateIdentityCommand(sql, connection, userId, projectId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<AuthProjectItem>();
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthProjectItem
            {
                ProjectId = reader.GetInt64(0),
                ProjectCode = reader.GetString(1),
                ProjectNameTh = reader.GetString(2),
                ProjectNameEn = reader.IsDBNull(3) ? null : reader.GetString(3),
                IsDefault = true,
                CanAccess = reader.GetBoolean(4),
                CanLoginAsUser = reader.GetBoolean(5)
            });
        }

        return result;
    }

    private static async Task<List<AuthCompanyItem>> LoadPartnerCompaniesAsync(
        SqlConnection connection,
        long partnerUserId,
        long partnerId,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT company.CompanyID, company.CompanyCode, company.CompanyNameTH,
                   company.CompanyNameEN
            FROM dbo.TDADCompany AS company
            WHERE company.PartnerID = @PartnerID
              AND company.IsActive = 1
              AND EXISTS
              (
                  SELECT 1
                  FROM dbo.TDADPartnerUser AS u
                  INNER JOIN dbo.TDADProject AS project
                      ON project.ProjectID = @ProjectID
                     AND project.IsActive = 1
                  WHERE u.PartnerUserID = @UserID
                    AND u.PartnerID = @PartnerID
                    AND u.IsActive = 1
                    AND {{AuthenticationProjectAccess.PartnerSql}}
              )
            ORDER BY company.CompanyCode;
            """;

        await using var command = CreateIdentityCommand(sql, connection, partnerUserId, projectId);
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<AuthCompanyItem>();
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(ReadCompany(reader));
        }

        return result;
    }

    private static async Task<List<AuthCompanyItem>> LoadUserCompaniesAsync(
        SqlConnection connection,
        long userId,
        long companyId,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT company.CompanyID, company.CompanyCode, company.CompanyNameTH,
                   company.CompanyNameEN,
                   CAST(CASE WHEN EXISTS
                   (
                       SELECT 1 FROM dbo.TDADUserProject AS userProject
                       WHERE userProject.UserID = u.UserID
                         AND userProject.CompanyID = u.CompanyID
                         AND userProject.ProjectID = @ProjectID
                         AND userProject.IsActive = 1
                         AND userProject.IsDefault = 1
                   ) THEN 1 ELSE 0 END AS bit) AS IsDefault
            FROM dbo.TDADUser AS u
            INNER JOIN dbo.TDADCompany AS company
                ON company.CompanyID = u.CompanyID
               AND company.IsActive = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            WHERE u.UserID = @UserID
              AND u.CompanyID = @CompanyID
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.CompanySql}};
            """;

        await using var command = CreateIdentityCommand(sql, connection, userId, projectId);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<AuthCompanyItem>();
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthCompanyItem
            {
                CompanyId = reader.GetInt64(0),
                CompanyCode = reader.GetString(1),
                CompanyNameTh = reader.GetString(2),
                CompanyNameEn = reader.IsDBNull(3) ? null : reader.GetString(3),
                IsDefault = reader.GetBoolean(4)
            });
        }

        return result;
    }

    private static async Task<List<AuthBranchItem>> LoadUserBranchesAsync(
        SqlConnection connection,
        long userId,
        long companyId,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT branch.BranchID, branch.CompanyID, branch.BranchCode,
                   branch.BranchNameTH, branch.BranchNameEN, userBranch.IsDefault
            FROM dbo.TDADUser AS u
            INNER JOIN dbo.TDADUserBranch AS userBranch
                ON userBranch.UserID = u.UserID
               AND userBranch.CompanyID = u.CompanyID
               AND userBranch.IsActive = 1
            INNER JOIN dbo.TDADBranch AS branch
                ON branch.BranchID = userBranch.BranchID
               AND branch.CompanyID = userBranch.CompanyID
               AND branch.IsActive = 1
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            WHERE u.UserID = @UserID
              AND u.CompanyID = @CompanyID
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.CompanySql}}
            ORDER BY userBranch.IsDefault DESC, branch.BranchCode;
            """;

        await using var command = CreateIdentityCommand(sql, connection, userId, projectId);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<AuthBranchItem>();
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthBranchItem
            {
                BranchId = reader.GetInt64(0),
                CompanyId = reader.GetInt64(1),
                BranchCode = reader.GetString(2),
                BranchNameTh = reader.GetString(3),
                BranchNameEn = reader.IsDBNull(4) ? null : reader.GetString(4),
                IsDefault = reader.GetBoolean(5)
            });
        }

        return result;
    }

    private static async Task<List<AuthProjectItem>> LoadUserProjectAsync(
        SqlConnection connection,
        long userId,
        long companyId,
        long projectId,
        CancellationToken cancellationToken)
    {
        var sql = $$"""
            SELECT project.ProjectID, project.ProjectCode, project.ProjectNameTH,
                   project.ProjectNameEN,
                   CAST(CASE WHEN EXISTS
                   (
                       SELECT 1 FROM dbo.TDADUserProject AS userProject
                       WHERE userProject.UserID = u.UserID
                         AND userProject.CompanyID = u.CompanyID
                         AND userProject.ProjectID = project.ProjectID
                         AND userProject.IsActive = 1
                         AND userProject.IsDefault = 1
                   ) THEN 1 ELSE 0 END AS bit) AS IsDefault
            FROM dbo.TDADUser AS u
            INNER JOIN dbo.TDADProject AS project
                ON project.ProjectID = @ProjectID
               AND project.IsActive = 1
            WHERE u.UserID = @UserID
              AND u.CompanyID = @CompanyID
              AND u.IsActive = 1
              AND {{AuthenticationProjectAccess.CompanySql}};
            """;

        await using var command = CreateIdentityCommand(sql, connection, userId, projectId);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var result = new List<AuthProjectItem>();
        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthProjectItem
            {
                ProjectId = reader.GetInt64(0),
                ProjectCode = reader.GetString(1),
                ProjectNameTh = reader.GetString(2),
                ProjectNameEn = reader.IsDBNull(3) ? null : reader.GetString(3),
                IsDefault = reader.GetBoolean(4),
                CanAccess = true,
                CanLoginAsUser = false
            });
        }

        return result;
    }

    private bool TryResolveTokenIdentity(out TokenIdentity identity)
    {
        identity = default;
        var userType = User.FindFirstValue("user_type")?.Trim().ToUpperInvariant();
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)
            || projectId <= 0
            || userType is null)
        {
            return false;
        }

        var (claimName, subjectPrefix) = userType switch
        {
            AuthUserTypes.LaooSupport => ("laoo_user_id", "laoo:"),
            AuthUserTypes.PartnerUser => ("partner_user_id", "partner:"),
            AuthUserTypes.CompanyUser => ("user_id", "user:"),
            _ => (string.Empty, string.Empty)
        };
        if (claimName.Length == 0) return false;

        var claimId = ReadPositiveLongClaim(claimName);
        var subjectId = ReadSubjectId(subjectPrefix);
        if (claimId.HasValue && subjectId.HasValue && claimId != subjectId)
        {
            return false;
        }

        var resolvedId = claimId ?? subjectId;
        if (!resolvedId.HasValue) return false;
        identity = new TokenIdentity(userType, resolvedId.Value, projectId);
        return true;
    }

    private long? ReadSubjectId(string expectedPrefix)
    {
        var subject = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
                      ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(subject)
            || !subject.StartsWith(expectedPrefix, StringComparison.OrdinalIgnoreCase)
            || !long.TryParse(subject[expectedPrefix.Length..], out var id)
            || id <= 0)
        {
            return null;
        }

        return id;
    }

    private long? ReadPositiveLongClaim(string claimName) =>
        long.TryParse(User.FindFirstValue(claimName), out var id) && id > 0 ? id : null;

    private ActionResult<PostLoginContextResponse> IdentityNotFound() =>
        NotFound(new { message = "Authenticated identity is unavailable for this project." });

    private static SqlCommand CreateIdentityCommand(
        string sql,
        SqlConnection connection,
        long userId,
        long projectId)
    {
        var command = new SqlCommand(sql, connection) { CommandTimeout = 15 };
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = userId;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        return command;
    }

    private static AuthCompanyItem ReadCompany(SqlDataReader reader) => new()
    {
        CompanyId = reader.GetInt64(0),
        CompanyCode = reader.GetString(1),
        CompanyNameTh = reader.GetString(2),
        CompanyNameEn = reader.IsDBNull(3) ? null : reader.GetString(3),
        IsDefault = false
    };

    private readonly record struct TokenIdentity(
        string UserType,
        long SubjectId,
        long ProjectId);
}
