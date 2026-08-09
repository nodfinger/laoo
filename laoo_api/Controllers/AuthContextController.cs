using System.Data;
using System.Security.Claims;
using Laoo.Api.Models.Auth;
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
        var username = ResolveUsernameFromToken();

        if (string.IsNullOrWhiteSpace(username))
        {
            return Unauthorized(new
            {
                message = "Token does not contain a usable username claim."
            });
        }

        var normalizedUsername = username.Trim().ToUpperInvariant();

        var connectionString =
            _configuration.GetConnectionString("LaooDatabase");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            _logger.LogError(
                "Connection string 'LaooDatabase' is not configured.");

            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new
                {
                    message = "Authentication database connection is not configured."
                });
        }

        await using var connection =
            new SqlConnection(connectionString);

        await connection.OpenAsync(cancellationToken);

        var laooUser = await FindLaooUserAsync(
            connection,
            normalizedUsername,
            cancellationToken);

        if (laooUser is not null)
        {
            var projects = await LoadLaooProjectsAsync(
                connection,
                laooUser.LaooUserID,
                cancellationToken);

            return Ok(new PostLoginContextResponse
            {
                UserType = AuthUserTypes.LaooSupport,
                UserId = laooUser.LaooUserID,
                Username = laooUser.Username,
                DisplayName = laooUser.DisplayName,
                IsSupportUser = laooUser.IsSupportUser,
                CanLoginAsUser = laooUser.CanLoginAsUser,
                Projects = projects
            });
        }

        var normalUser = await FindNormalUserAsync(
            connection,
            normalizedUsername,
            cancellationToken);

        if (normalUser is null)
        {
            return NotFound(new
            {
                message = "Authenticated user was not found in TDADLaooUser or TDADUser."
            });
        }

        var companies = await LoadUserCompaniesAsync(
            connection,
            normalUser.UserID,
            cancellationToken);

        var branches = await LoadUserBranchesAsync(
            connection,
            normalUser.UserID,
            cancellationToken);

        var projectsForUser = await LoadUserProjectsAsync(
            connection,
            normalUser.UserID,
            cancellationToken);

        return Ok(new PostLoginContextResponse
        {
            UserType = AuthUserTypes.CompanyUser,
            UserId = normalUser.UserID,
            Username = normalUser.Username,
            DisplayName = normalUser.DisplayName,
            IsSupportUser = false,
            CanLoginAsUser = false,
            Companies = companies,
            Branches = branches,
            Projects = projectsForUser
        });
    }

    private string? ResolveUsernameFromToken()
    {
        var candidates = new[]
        {
            User.Identity?.Name,
            User.FindFirstValue(ClaimTypes.Name),
            User.FindFirstValue("username"),
            User.FindFirstValue("preferred_username"),
            User.FindFirstValue("unique_name")
        };

        return candidates.FirstOrDefault(
            value => !string.IsNullOrWhiteSpace(value));
    }

    private static async Task<LaooUserRow?> FindLaooUserAsync(
        SqlConnection connection,
        string normalizedUsername,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (1)
                LaooUserID,
                Username,
                DisplayName,
                IsSupportUser,
                CanLoginAsUser
            FROM TDADLaooUser
            WHERE NormalizedUsername = @NormalizedUsername
              AND IsActive = 1;
            """;

        await using var command =
            new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter(
                "@NormalizedUsername",
                SqlDbType.NVarChar,
                100)
            {
                Value = normalizedUsername
            });

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new LaooUserRow(
            reader.GetInt64(reader.GetOrdinal("LaooUserID")),
            reader.GetString(reader.GetOrdinal("Username")),
            reader.GetString(reader.GetOrdinal("DisplayName")),
            reader.GetBoolean(reader.GetOrdinal("IsSupportUser")),
            reader.GetBoolean(reader.GetOrdinal("CanLoginAsUser")));
    }

    private static async Task<NormalUserRow?> FindNormalUserAsync(
        SqlConnection connection,
        string normalizedUsername,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT TOP (1)
                UserID,
                Username,
                DisplayName
            FROM TDADUser
            WHERE NormalizedUsername = @NormalizedUsername
              AND IsActive = 1;
            """;

        await using var command =
            new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter(
                "@NormalizedUsername",
                SqlDbType.NVarChar,
                100)
            {
                Value = normalizedUsername
            });

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new NormalUserRow(
            reader.GetInt64(reader.GetOrdinal("UserID")),
            reader.GetString(reader.GetOrdinal("Username")),
            reader.GetString(reader.GetOrdinal("DisplayName")));
    }

    private static async Task<List<AuthProjectItem>> LoadLaooProjectsAsync(
        SqlConnection connection,
        long laooUserId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                P.ProjectID,
                P.ProjectCode,
                P.ProjectNameTH,
                P.ProjectNameEN,
                UP.CanAccess,
                UP.CanLoginAsUser
            FROM TDADLaooUserProject UP
            INNER JOIN TDADProject P
                ON P.ProjectID = UP.ProjectID
            WHERE UP.LaooUserID = @LaooUserID
              AND UP.IsActive = 1
              AND P.IsActive = 1
              AND UP.CanAccess = 1
            ORDER BY P.ProjectCode;
            """;

        await using var command =
            new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter(
                "@LaooUserID",
                SqlDbType.BigInt)
            {
                Value = laooUserId
            });

        var result = new List<AuthProjectItem>();

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthProjectItem
            {
                ProjectId =
                    reader.GetInt64(reader.GetOrdinal("ProjectID")),
                ProjectCode =
                    reader.GetString(reader.GetOrdinal("ProjectCode")),
                ProjectNameTh =
                    reader.GetString(reader.GetOrdinal("ProjectNameTH")),
                ProjectNameEn =
                    reader.IsDBNull(reader.GetOrdinal("ProjectNameEN"))
                        ? null
                        : reader.GetString(reader.GetOrdinal("ProjectNameEN")),
                IsDefault = false,
                CanAccess =
                    reader.GetBoolean(reader.GetOrdinal("CanAccess")),
                CanLoginAsUser =
                    reader.GetBoolean(reader.GetOrdinal("CanLoginAsUser"))
            });
        }

        return result;
    }

    private static async Task<List<AuthCompanyItem>> LoadUserCompaniesAsync(
        SqlConnection connection,
        long userId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                C.CompanyID,
                C.CompanyCode,
                C.CompanyNameTH,
                C.CompanyNameEN,
                UC.IsDefault
            FROM TDADUserCompany UC
            INNER JOIN TDADCompany C
                ON C.CompanyID = UC.CompanyID
            WHERE UC.UserID = @UserID
              AND UC.IsActive = 1
              AND C.IsActive = 1
            ORDER BY
                UC.IsDefault DESC,
                C.CompanyCode;
            """;

        await using var command =
            new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter("@UserID", SqlDbType.BigInt)
            {
                Value = userId
            });

        var result = new List<AuthCompanyItem>();

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthCompanyItem
            {
                CompanyId =
                    reader.GetInt64(reader.GetOrdinal("CompanyID")),
                CompanyCode =
                    reader.GetString(reader.GetOrdinal("CompanyCode")),
                CompanyNameTh =
                    reader.GetString(reader.GetOrdinal("CompanyNameTH")),
                CompanyNameEn =
                    reader.IsDBNull(reader.GetOrdinal("CompanyNameEN"))
                        ? null
                        : reader.GetString(reader.GetOrdinal("CompanyNameEN")),
                IsDefault =
                    reader.GetBoolean(reader.GetOrdinal("IsDefault"))
            });
        }

        return result;
    }

    private static async Task<List<AuthBranchItem>> LoadUserBranchesAsync(
        SqlConnection connection,
        long userId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                B.BranchID,
                B.CompanyID,
                B.BranchCode,
                B.BranchNameTH,
                B.BranchNameEN,
                UB.IsDefault
            FROM TDADUserBranch UB
            INNER JOIN TDADBranch B
                ON B.BranchID = UB.BranchID
               AND B.CompanyID = UB.CompanyID
            WHERE UB.UserID = @UserID
              AND UB.IsActive = 1
              AND B.IsActive = 1
            ORDER BY
                UB.IsDefault DESC,
                B.CompanyID,
                B.BranchCode;
            """;

        await using var command =
            new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter("@UserID", SqlDbType.BigInt)
            {
                Value = userId
            });

        var result = new List<AuthBranchItem>();

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthBranchItem
            {
                BranchId =
                    reader.GetInt64(reader.GetOrdinal("BranchID")),
                CompanyId =
                    reader.GetInt64(reader.GetOrdinal("CompanyID")),
                BranchCode =
                    reader.GetString(reader.GetOrdinal("BranchCode")),
                BranchNameTh =
                    reader.GetString(reader.GetOrdinal("BranchNameTH")),
                BranchNameEn =
                    reader.IsDBNull(reader.GetOrdinal("BranchNameEN"))
                        ? null
                        : reader.GetString(reader.GetOrdinal("BranchNameEN")),
                IsDefault =
                    reader.GetBoolean(reader.GetOrdinal("IsDefault"))
            });
        }

        return result;
    }

    private static async Task<List<AuthProjectItem>> LoadUserProjectsAsync(
        SqlConnection connection,
        long userId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT
                P.ProjectID,
                P.ProjectCode,
                P.ProjectNameTH,
                P.ProjectNameEN,
                UP.IsDefault
            FROM TDADUserProject UP
            INNER JOIN TDADProject P
                ON P.ProjectID = UP.ProjectID
            WHERE UP.UserID = @UserID
              AND UP.IsActive = 1
              AND P.IsActive = 1
            ORDER BY
                UP.IsDefault DESC,
                P.ProjectCode;
            """;

        await using var command =
            new SqlCommand(sql, connection);

        command.Parameters.Add(
            new SqlParameter("@UserID", SqlDbType.BigInt)
            {
                Value = userId
            });

        var result = new List<AuthProjectItem>();

        await using var reader =
            await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new AuthProjectItem
            {
                ProjectId =
                    reader.GetInt64(reader.GetOrdinal("ProjectID")),
                ProjectCode =
                    reader.GetString(reader.GetOrdinal("ProjectCode")),
                ProjectNameTh =
                    reader.GetString(reader.GetOrdinal("ProjectNameTH")),
                ProjectNameEn =
                    reader.IsDBNull(reader.GetOrdinal("ProjectNameEN"))
                        ? null
                        : reader.GetString(reader.GetOrdinal("ProjectNameEN")),
                IsDefault =
                    reader.GetBoolean(reader.GetOrdinal("IsDefault")),
                CanAccess = true,
                CanLoginAsUser = false
            });
        }

        return result;
    }

    private sealed record LaooUserRow(
        long LaooUserID,
        string Username,
        string DisplayName,
        bool IsSupportUser,
        bool CanLoginAsUser);

    private sealed record NormalUserRow(
        long UserID,
        string Username,
        string DisplayName);
}
