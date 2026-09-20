using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace laoo_api.Controllers;

[ApiController]
[Authorize]
[Route("api/laoo-menu-management")]
public sealed class LaooMenuManagementController(IConfiguration configuration) : ControllerBase
{
    private const string ScreenCode = "01007";

    [HttpGet("caption")]
    public async Task<IActionResult> Caption(CancellationToken token)
    {
        if (!IsLaooUser()) return Forbid();
        await using var connection = await OpenAsync(token);
        await using var command = new SqlCommand("SELECT TOP 1 MenuName FROM dbo.TDADMainMenu WHERE MenuCode=@screen AND IsActive=1", connection);
        command.Parameters.AddWithValue("@screen", ScreenCode);
        var caption = Convert.ToString(await command.ExecuteScalarAsync(token));
        return string.IsNullOrWhiteSpace(caption)
            ? NotFound(new { message = "Menu management screen is unavailable." })
            : Ok(new { caption });
    }

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] string? projectCode, CancellationToken token)
    {
        if (!IsLaooUser()) return Forbid();
        await using var connection = await OpenAsync(token);
        const string sql = """
WITH MenuProjects AS (
  SELECT PM.MenuCode, STRING_AGG(P.ProjectCode, ', ') WITHIN GROUP (ORDER BY P.ProjectCode) AS ProjectCodes
  FROM dbo.TDADProjectMenu PM
  JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID
  GROUP BY PM.MenuCode
), FilteredMenus AS (
  SELECT M.MenuCode,M.MenuGroupCode,M.MenuName,M.SortOrder,M.ScreenType,M.RouteName,M.RoutePath,MP.ProjectCodes
  FROM dbo.TDADMainMenu M
  LEFT JOIN MenuProjects MP ON MP.MenuCode=M.MenuCode
  WHERE (@projectCode IS NULL OR EXISTS (
    SELECT 1 FROM dbo.TDADProjectMenu PM JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID
    WHERE PM.MenuCode=M.MenuCode AND P.ProjectCode=@projectCode))
)
SELECT G.MenuGroupCode,G.MenuGroupName,G.SortOrder,FM.MenuCode,FM.MenuName,FM.SortOrder AS MenuSortOrder,
       FM.ScreenType,FM.RouteName,FM.RoutePath,FM.ProjectCodes
FROM dbo.TDADMenuGroup G
JOIN FilteredMenus FM ON FM.MenuGroupCode=G.MenuGroupCode
ORDER BY G.SortOrder,G.MenuGroupCode,FM.MenuSortOrder,FM.MenuCode;
SELECT ProjectCode,ProjectName FROM dbo.TDADProject WHERE IsActive=1 ORDER BY ProjectName,ProjectCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@projectCode", string.IsNullOrWhiteSpace(projectCode) ? DBNull.Value : projectCode.Trim());
        await using var reader = await command.ExecuteReaderAsync(token);
        var groups = new Dictionary<string, MenuGroupDto>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(token))
        {
            var code = reader.GetString(0).Trim();
            if (!groups.TryGetValue(code, out var group))
            {
                group = new MenuGroupDto(code, reader.GetString(1), reader.GetInt32(2), []);
                groups[code] = group;
            }
            group.Menus.Add(new MainMenuDto(reader.GetString(3).Trim(), reader.GetString(4), reader.GetInt32(5), reader.IsDBNull(6) ? null : reader.GetInt32(6), reader.IsDBNull(7) ? null : reader.GetString(7), reader.IsDBNull(8) ? null : reader.GetString(8), reader.IsDBNull(9) ? "" : reader.GetString(9)));
        }
        await reader.NextResultAsync(token);
        var systems = new List<ProjectDto>();
        while (await reader.ReadAsync(token)) systems.Add(new ProjectDto(reader.GetString(0), reader.GetString(1)));
        return Ok(new { groups = groups.Values, systems });
    }

    [HttpPut]
    public async Task<IActionResult> Save(BulkMenuUpdateRequest request, CancellationToken token)
    {
        if (!IsLaooUser()) return Forbid();
        if (request.Groups.Count == 0 && request.Menus.Count == 0) return BadRequest(new { message = "No changes were supplied." });
        if (request.Groups.Any(x => string.IsNullOrWhiteSpace(x.MenuGroupCode) || string.IsNullOrWhiteSpace(x.MenuGroupName) || x.SortOrder < 0) ||
            request.Menus.Any(x => string.IsNullOrWhiteSpace(x.MenuCode) || string.IsNullOrWhiteSpace(x.MenuName) || x.SortOrder < 0))
            return BadRequest(new { message = "Menu names are required and sort order cannot be negative." });

        await using var connection = await OpenAsync(token);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(token);
        try
        {
            foreach (var group in request.Groups)
            {
                await using var command = new SqlCommand("UPDATE dbo.TDADMenuGroup SET MenuGroupName=@name,SortOrder=@sort,UpdateDate=SYSUTCDATETIME() WHERE MenuGroupCode=@code", connection, transaction);
                command.Parameters.AddWithValue("@code", group.MenuGroupCode.Trim());
                command.Parameters.AddWithValue("@name", group.MenuGroupName.Trim());
                command.Parameters.AddWithValue("@sort", group.SortOrder);
                if (await command.ExecuteNonQueryAsync(token) != 1) return await RollbackNotFound(transaction, "Menu group", group.MenuGroupCode);
            }
            foreach (var menu in request.Menus)
            {
                await using var command = new SqlCommand("UPDATE dbo.TDADMainMenu SET MenuName=@name,SortOrder=@sort,UpdateDate=SYSUTCDATETIME() WHERE MenuCode=@code", connection, transaction);
                command.Parameters.AddWithValue("@code", menu.MenuCode.Trim());
                command.Parameters.AddWithValue("@name", menu.MenuName.Trim());
                command.Parameters.AddWithValue("@sort", menu.SortOrder);
                if (await command.ExecuteNonQueryAsync(token) != 1) return await RollbackNotFound(transaction, "Menu", menu.MenuCode);
            }
            await transaction.CommitAsync(token);
            return NoContent();
        }
        catch { await transaction.RollbackAsync(token); throw; }
    }

    private bool IsLaooUser() => string.Equals(User.FindFirstValue("user_type"), "LAOO_SUPPORT", StringComparison.OrdinalIgnoreCase);
    private async Task<SqlConnection> OpenAsync(CancellationToken token) { var c = new SqlConnection(configuration.GetConnectionString("LaooDatabase")); await c.OpenAsync(token); return c; }
    private static async Task<IActionResult> RollbackNotFound(SqlTransaction transaction, string subject, string code) { await transaction.RollbackAsync(); return new NotFoundObjectResult(new { message = $"{subject} {code} was not found." }); }

    public sealed record ProjectDto(string ProjectCode, string ProjectName);
    public sealed record MainMenuDto(string MenuCode, string MenuName, int SortOrder, int? ScreenType, string? RouteName, string? RoutePath, string ProjectCodes);
    public sealed record MenuGroupDto(string MenuGroupCode, string MenuGroupName, int SortOrder, List<MainMenuDto> Menus);
    public sealed record MenuGroupUpdate(string MenuGroupCode, string MenuGroupName, int SortOrder);
    public sealed record MainMenuUpdate(string MenuCode, string MenuName, int SortOrder);
    public sealed record BulkMenuUpdateRequest(List<MenuGroupUpdate> Groups, List<MainMenuUpdate> Menus);
}
