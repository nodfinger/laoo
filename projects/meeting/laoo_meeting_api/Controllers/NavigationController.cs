using System.Data;
using System.Security.Claims;
using LaooMeetingApi.Models.Navigation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

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
        if (userType is not ("PARTNER_USER" or "COMPANY_USER" or "LAOO_SUPPORT"))
            return Forbid();
        if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId))
            return Forbid();

        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        var admin = await IsAdminAsync(connection, userType!, cancellationToken);
        var allowedFeatures = admin ? null : await LoadAllowedFeaturesAsync(connection, userType!, cancellationToken);
        var audienceType = userType == "PARTNER_USER" ? "P" : userType == "COMPANY_USER" ? "C" : "L";
        const string sql = """
SELECT G.MenuGroupCode, G.MenuGroupName, G.IconName AS GroupIconName, G.SortOrder AS GroupSortOrder,
       G.IsExpandedDefault, M.MenuCode, M.MenuName, M.RouteName, M.RoutePath, M.FeatureCode,
       M.IconName, M.SortOrder, M.IsFavoriteAllowed
FROM dbo.TDADMenuGroup G
INNER JOIN dbo.TDADProjectMenuGroup PG
    ON PG.MenuGroupCode = G.MenuGroupCode AND PG.ProjectID = @ProjectID AND PG.IsActive = 1
INNER JOIN dbo.TDADMainMenu M ON M.MenuGroupCode = G.MenuGroupCode AND M.IsActive = 1 AND M.IsVisible = 1
INNER JOIN dbo.TDADProjectMenu PM
    ON PM.MenuCode = M.MenuCode AND PM.MenuGroupCode = G.MenuGroupCode
   AND PM.ProjectID = @ProjectID AND PM.IsActive = 1
WHERE G.IsActive = 1
  AND UPPER(LTRIM(RTRIM(G.AudienceType))) IN (N'A',@AudienceType)
  AND NOT (@AudienceType='L' AND M.MenuCode='05002')
ORDER BY PG.SortOrder, PM.SortOrder, M.MenuCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@AudienceType", SqlDbType.Char).Value = audienceType;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var all = new List<(NavigationMenuGroupResponse Group, NavigationMenuItemResponse Item)>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var group = new NavigationMenuGroupResponse { MenuGroupCode = reader.GetString(0).Trim(), MenuGroupName = reader.GetString(1), IconName = N(reader, 2), SortOrder = reader.GetInt32(3), IsExpandedDefault = reader.GetBoolean(4) };
            var item = new NavigationMenuItemResponse { MenuCode = reader.GetString(5), MenuName = reader.GetString(6), RouteName = N(reader, 7), RoutePath = N(reader, 8), FeatureCode = N(reader, 9), IconName = N(reader, 10), SortOrder = reader.GetInt32(11), IsFavoriteAllowed = reader.GetBoolean(12) };
            if (admin ||
                allowedFeatures!.Contains(item.MenuCode) ||
                (item.FeatureCode is not null && allowedFeatures.Contains(item.FeatureCode)))
            {
                all.Add((group, item));
            }
        }
        return Ok(all.GroupBy(x => x.Group.MenuGroupCode).Select(g => { var first = g.First().Group; first.Items.AddRange(g.Select(x => x.Item)); return first; }).ToList());
    }

    private async Task<bool> IsAdminAsync(SqlConnection connection, string userType, CancellationToken token)
    {
        var sql = userType == "LAOO_SUPPORT"
            ? """
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADLaooUserPermission UP
    INNER JOIN dbo.TDADPermission P
        ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
       AND P.ScreenCode=N'*' AND P.ActionCode=N'ADMIN' AND P.IsActive=1
    INNER JOIN dbo.TDADLaooUser U
        ON U.LaooUserID=UP.LaooUserID AND U.IsSupportUser=1 AND U.IsActive=1
    WHERE UP.LaooUserID=@ID AND UP.ProjectID=@ProjectID
      AND UP.IsAllowed=1 AND UP.IsActive=1
) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
"""
            : userType == "PARTNER_USER"
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
            var raw = userType == "LAOO_SUPPORT"
                ? User.FindFirstValue("laoo_user_id")
                : User.FindFirstValue("user_id");
            if (!long.TryParse(raw, out var id)) return false;
            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = id;
            if (userType == "LAOO_SUPPORT")
            {
                if (!long.TryParse(User.FindFirstValue("project_id"), out var projectId)) return false;
                command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
            }
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
SELECT P.ScreenCode
FROM dbo.TDADPartnerUserPermission UP
INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID
WHERE U.NormalizedUsername=@Username AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW'
UNION
SELECT RP.MenuCode
FROM dbo.TDADPartnerUser U
INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID
INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID
INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID
INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.ActionCode='VIEW' AND RP.IsAllowed=1
WHERE U.NormalizedUsername=@Username AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()));
""" : $"""
SELECT P.ScreenCode
FROM dbo.{permissionTable} UP
INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
WHERE UP.{idColumn}=@ID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW'
UNION
SELECT RP.MenuCode
FROM dbo.TDADUser U
INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID
INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@ProjectID
INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.ActionCode='VIEW' AND RP.IsAllowed=1
WHERE U.UserID=@ID AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()));
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
