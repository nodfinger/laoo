using System.Data;
using System.Security.Claims;
using LaooApi.Models.Navigation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooApi.Controllers;

[ApiController]
[Route("api/navigation")]
[Authorize]
public sealed class NavigationController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public NavigationController(IConfiguration configuration) => _configuration = configuration;

    [HttpGet("menus")]
    public async Task<ActionResult<List<NavigationMenuGroupResponse>>> GetMenus(CancellationToken cancellationToken)
    {
        var userType = User.FindFirstValue("user_type");
        var groupCodes = userType switch
        {
            "PARTNER_USER" => new[] { "05", "06", "07", "11" },
            "COMPANY_USER" => new[] { "05", "08", "09", "10" },
            "LAOO_SUPPORT" => new[] { "01", "02", "03", "04", "05", "12" },
            _ => Array.Empty<string>()
        };
        if (groupCodes.Length == 0) return Forbid();

        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        var admin = await IsAdminAsync(connection, userType!, cancellationToken);
        var allowedFeatures = admin ? null : await LoadAllowedFeaturesAsync(connection, userType!, cancellationToken);
        const string sql = """
SELECT G.MenuGroupCode, G.MenuGroupName, G.IconName AS GroupIconName, G.SortOrder AS GroupSortOrder,
       G.IsExpandedDefault, M.MenuCode, M.MenuName, M.RouteName, M.RoutePath, M.FeatureCode,
       M.IconName, M.SortOrder, M.IsFavoriteAllowed
FROM dbo.TDADMenuGroup G
INNER JOIN dbo.TDADMainMenu M ON M.MenuGroupCode = G.MenuGroupCode AND M.IsActive = 1 AND M.IsVisible = 1
WHERE G.IsActive = 1 AND G.MenuGroupCode IN ('01','02','03','04','05','06','07','08','09','10','11','12')
ORDER BY G.SortOrder, M.SortOrder, M.MenuCode;
""";
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var all = new List<(NavigationMenuGroupResponse Group, NavigationMenuItemResponse Item)>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var group = new NavigationMenuGroupResponse { MenuGroupCode = reader.GetString(0).Trim(), MenuGroupName = reader.GetString(1), IconName = N(reader, 2), SortOrder = reader.GetInt32(3), IsExpandedDefault = reader.GetBoolean(4) };
            var item = new NavigationMenuItemResponse { MenuCode = reader.GetString(5), MenuName = reader.GetString(6), RouteName = N(reader, 7), RoutePath = N(reader, 8), FeatureCode = N(reader, 9), IconName = N(reader, 10), SortOrder = reader.GetInt32(11), IsFavoriteAllowed = reader.GetBoolean(12) };
            if (groupCodes.Contains(group.MenuGroupCode) &&
                item.FeatureCode is not null &&
                (admin || allowedFeatures!.Contains(item.FeatureCode)))
            {
                all.Add((group, item));
            }
        }
        return Ok(all.GroupBy(x => x.Group.MenuGroupCode).Select(g => { var first = g.First().Group; first.Items.AddRange(g.Select(x => x.Item)); return first; }).ToList());
    }

    private async Task<bool> IsAdminAsync(SqlConnection connection, string userType, CancellationToken token)
    {
        if (userType == "LAOO_SUPPORT") return false;
        var sql = userType == "PARTNER_USER"
            ? "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE PartnerID=@PartnerID AND NormalizedUsername=@Username AND IsPartnerAdmin=1 AND IsActive=1) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END"
            : "SELECT IsCompanyAdmin FROM dbo.TDADUser WHERE UserID=@ID AND IsActive=1";
        await using var command = new SqlCommand(sql, connection);
        if (userType == "PARTNER_USER")
        {
            var partnerId = User.FindFirstValue("partner_id");
            if (!long.TryParse(partnerId, out var parsedPartnerId)) return false;
            command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = parsedPartnerId;
            command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = Username().ToUpperInvariant();
        }
        else
        {
            var raw = User.FindFirstValue("user_id");
            if (!long.TryParse(raw, out var id)) return false;
            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = id;
        }
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<HashSet<string>> LoadAllowedFeaturesAsync(SqlConnection connection, string userType, CancellationToken token)
    {
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return [];
        var permissionTable = userType == "PARTNER_USER" ? "TDADPartnerUserPermission" : userType == "COMPANY_USER" ? "TDADUserPermission" : "TDADLaooUserPermission";
        var idColumn = userType == "PARTNER_USER" ? "PartnerUserID" : userType == "COMPANY_USER" ? "UserID" : "LaooUserID";
        var claimName = userType == "COMPANY_USER" ? "user_id" : "laoo_user_id";
        var raw = User.FindFirstValue(claimName)?.Replace("laoo:", "");
        var sql = userType == "PARTNER_USER" ? $"""
SELECT P.ScreenCode FROM dbo.TDADPartnerUserPermission UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID WHERE U.NormalizedUsername=@Username AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW';
""" : $"""
SELECT P.ScreenCode FROM dbo.{permissionTable} UP INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.{idColumn}=@ID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW';
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        if (userType == "PARTNER_USER") command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = Username().ToUpperInvariant();
        else
        {
            if (!long.TryParse(raw, out var id)) return [];
            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = id;
        }
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(token)) result.Add(reader.GetString(0));
        return result;
    }

    private string Username() => (User.Identity?.Name ?? User.FindFirstValue("unique_name") ?? string.Empty).Trim();

    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
}
