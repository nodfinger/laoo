using System.Data;
using System.Security.Claims;
using LaooMeetingApi.Models.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController]
[Route("api/auth")]
[Authorize]
public sealed class PermissionController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public PermissionController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    [HttpGet("permissions")]
    [ProducesResponseType(typeof(PermissionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<PermissionResponse>> GetPermissions(
        CancellationToken cancellationToken)
    {
        var projectId = ReadLongClaim("project_id");
        var projectCode = User.FindFirstValue("project_code");

        if (!projectId.HasValue || string.IsNullOrWhiteSpace(projectCode))
        {
            return BadRequest(new { message = "JWT ไม่มี project_id หรือ project_code" });
        }

        var laooUserId = ReadLongClaim("laoo_user_id");
        var userId = ReadLongClaim("user_id");

        if (!laooUserId.HasValue && !userId.HasValue)
        {
            return Unauthorized(new { message = "JWT ไม่มี laoo_user_id หรือ user_id" });
        }

        var connectionString = _configuration.GetConnectionString("LaooDatabase");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new { message = "Authentication database connection is not configured." });
        }

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        List<PermissionRow> rows;
        string userType;

        if (laooUserId.HasValue)
        {
            userType = "LAOO_SUPPORT";
            rows = await LoadLaooUserPermissionsAsync(
                connection, laooUserId.Value, projectId.Value, cancellationToken);
        }
        else
        {
            userType = "COMPANY_USER";
            rows = await LoadCompanyUserPermissionsAsync(
                connection, userId!.Value, projectId.Value, cancellationToken);
        }

        var grouped = rows
            .GroupBy(x => new { x.ScreenCode, x.ScreenNameTh, x.ScreenNameEn })
            .OrderBy(g => g.Key.ScreenCode)
            .Select(g =>
            {
                var actions = g
                    .Select(x => x.ActionCode.Trim().ToUpperInvariant())
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .OrderBy(x => x)
                    .ToList();

                return new PermissionScreenItem
                {
                    ScreenCode = g.Key.ScreenCode,
                    ScreenNameTh = g.Key.ScreenNameTh,
                    ScreenNameEn = g.Key.ScreenNameEn,
                    CanView = actions.Contains("VIEW", StringComparer.OrdinalIgnoreCase),
                    Actions = actions
                };
            })
            .ToList();

        return Ok(new PermissionResponse
        {
            ProjectCode = projectCode!,
            ProjectId = projectId.Value,
            UserType = userType,
            Permissions = grouped
        });
    }

    private long? ReadLongClaim(string claimType)
    {
        var value = User.FindFirstValue(claimType);
        return long.TryParse(value, out var result) ? result : null;
    }

    private static async Task<List<PermissionRow>> LoadLaooUserPermissionsAsync(
        SqlConnection connection,
        long laooUserId,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    P.ScreenCode,
    P.ScreenNameTH,
    P.ScreenNameEN,
    P.ActionCode
FROM dbo.TDADLaooUserPermission UP
INNER JOIN dbo.TDADPermission P
    ON P.PermissionID = UP.PermissionID
   AND P.ProjectID = UP.ProjectID
WHERE UP.LaooUserID = @LaooUserID
  AND UP.ProjectID = @ProjectID
  AND UP.IsAllowed = 1
  AND UP.IsActive = 1
  AND P.IsActive = 1
ORDER BY P.ScreenCode, P.ActionCode;";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add(new SqlParameter("@LaooUserID", SqlDbType.BigInt) { Value = laooUserId });
        command.Parameters.Add(new SqlParameter("@ProjectID", SqlDbType.BigInt) { Value = projectId });

        return await ReadPermissionRowsAsync(command, cancellationToken);
    }

    private static async Task<List<PermissionRow>> LoadCompanyUserPermissionsAsync(
        SqlConnection connection,
        long userId,
        long projectId,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT
    P.ScreenCode,
    P.ScreenNameTH,
    P.ScreenNameEN,
    P.ActionCode
FROM dbo.TDADUserPermission UP
INNER JOIN dbo.TDADPermission P
    ON P.PermissionID = UP.PermissionID
   AND P.ProjectID = UP.ProjectID
WHERE UP.UserID = @UserID
  AND UP.ProjectID = @ProjectID
  AND UP.IsAllowed = 1
  AND UP.IsActive = 1
  AND P.IsActive = 1
ORDER BY P.ScreenCode, P.ActionCode;";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add(new SqlParameter("@UserID", SqlDbType.BigInt) { Value = userId });
        command.Parameters.Add(new SqlParameter("@ProjectID", SqlDbType.BigInt) { Value = projectId });

        return await ReadPermissionRowsAsync(command, cancellationToken);
    }

    private static async Task<List<PermissionRow>> ReadPermissionRowsAsync(
        SqlCommand command,
        CancellationToken cancellationToken)
    {
        var result = new List<PermissionRow>();

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new PermissionRow
            {
                ScreenCode = reader.GetString(reader.GetOrdinal("ScreenCode")),
                ScreenNameTh = reader.GetString(reader.GetOrdinal("ScreenNameTH")),
                ScreenNameEn = reader.IsDBNull(reader.GetOrdinal("ScreenNameEN"))
                    ? null
                    : reader.GetString(reader.GetOrdinal("ScreenNameEN")),
                ActionCode = reader.GetString(reader.GetOrdinal("ActionCode"))
            });
        }

        return result;
    }
}
