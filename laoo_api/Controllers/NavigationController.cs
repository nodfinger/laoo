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
        if (userType is not ("PARTNER_USER" or "COMPANY_USER" or "LAOO_SUPPORT"))
            return Forbid();
        if (LongClaim("project_id") is not long projectId)
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
  AND (
        ISNULL(G.OpenOption, 0) = 0
        OR @UserType <> N'COMPANY_USER'
        OR (
            ISNULL(G.OpenOption, 0) = 1
            AND M.FeatureCode IS NOT NULL
            AND EXISTS
            (
                SELECT 1
                FROM dbo.TDADCompanyFeature CF
                INNER JOIN dbo.TDADFeature F ON F.FeatureCode = CF.FeatureCode AND F.IsActive = 1
                WHERE CF.ProjectID = @ProjectID
                  AND CF.CompanyID = @CompanyID
                  AND CF.FeatureCode = M.FeatureCode
                  AND CF.IsEnabled = 1
                  AND (CF.StartDate IS NULL OR CF.StartDate <= CONVERT(date, SYSUTCDATETIME()))
                  AND (CF.ExpireDate IS NULL OR CF.ExpireDate >= CONVERT(date, SYSUTCDATETIME()))
            )
        )
      )
ORDER BY PG.SortOrder, PM.SortOrder, M.MenuCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@AudienceType", SqlDbType.Char).Value = audienceType;
        command.Parameters.Add("@UserType", SqlDbType.NVarChar, 30).Value = userType;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = LongClaim("company_id") is long companyId ? companyId : DBNull.Value;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var all = new List<(NavigationMenuGroupResponse Group, NavigationMenuItemResponse Item)>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var group = new NavigationMenuGroupResponse { MenuGroupCode = reader.GetString(0).Trim(), MenuGroupName = reader.GetString(1), IconName = N(reader, 2), SortOrder = reader.GetInt32(3), IsExpandedDefault = reader.GetBoolean(4) };
            var item = new NavigationMenuItemResponse { MenuCode = reader.GetString(5), MenuName = reader.GetString(6), RouteName = N(reader, 7), RoutePath = N(reader, 8), FeatureCode = N(reader, 9), IconName = N(reader, 10), SortOrder = reader.GetInt32(11), IsFavoriteAllowed = reader.GetBoolean(12) };
            if (admin || allowedFeatures!.Contains(item.MenuCode))
            {
                all.Add((group, item));
            }
        }
        return Ok(all.GroupBy(x => x.Group.MenuGroupCode).Select(g => { var first = g.First().Group; first.Items.AddRange(g.Select(x => x.Item)); return first; }).ToList());
    }

    private async Task<bool> IsAdminAsync(SqlConnection connection, string userType, CancellationToken token)
    {
        if (userType == "LAOO_SUPPORT")
        {
            if (LongClaim("laoo_user_id") is not long laooUserId ||
                LongClaim("project_id") is not long projectId) return false;
            const string laooAdminSql = """
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADLaooUserPermission UP
    INNER JOIN dbo.TDADPermission P
        ON P.PermissionID=UP.PermissionID
       AND P.ProjectID=UP.ProjectID
       AND P.ScreenCode=N'*'
       AND P.ActionCode=N'ADMIN'
       AND P.IsActive=1
    INNER JOIN dbo.TDADLaooUser U
        ON U.LaooUserID=UP.LaooUserID
       AND U.IsSupportUser=1
       AND U.IsActive=1
    WHERE UP.LaooUserID=@ID
      AND UP.ProjectID=@ProjectID
      AND UP.IsAllowed=1
      AND UP.IsActive=1
) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
""";
            await using var laooAdminCommand = new SqlCommand(laooAdminSql, connection);
            laooAdminCommand.Parameters.Add("@ID", SqlDbType.BigInt).Value = laooUserId;
            laooAdminCommand.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
            return Convert.ToBoolean(await laooAdminCommand.ExecuteScalarAsync(token));
        }
        var sql = userType == "PARTNER_USER"
            ? "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADPartnerUser WHERE PartnerUserID=@ID AND PartnerID=@OwnerID AND IsPartnerAdmin=1 AND IsActive=1) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END"
            : "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUser WHERE UserID=@ID AND CompanyID=@OwnerID AND IsCompanyAdmin=1 AND IsActive=1) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END";
        await using var command = new SqlCommand(sql, connection);
        if (userType == "PARTNER_USER")
        {
            if (LongClaim("partner_user_id") is not long partnerUserId ||
                LongClaim("partner_id") is not long partnerId) return false;
            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = partnerUserId;
            command.Parameters.Add("@OwnerID", SqlDbType.BigInt).Value = partnerId;
        }
        else
        {
            if (LongClaim("user_id") is not long userId ||
                LongClaim("company_id") is not long companyId) return false;
            command.Parameters.Add("@ID", SqlDbType.BigInt).Value = userId;
            command.Parameters.Add("@OwnerID", SqlDbType.BigInt).Value = companyId;
        }
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private async Task<HashSet<string>> LoadAllowedFeaturesAsync(SqlConnection connection, string userType, CancellationToken token)
    {
        if (LongClaim("project_id") is not long projectId) return [];
        long userId;
        long? ownerId = null;
        string sql;
        if (userType == "PARTNER_USER")
        {
            if (LongClaim("partner_user_id") is not long partnerUserId ||
                LongClaim("partner_id") is not long partnerId) return [];
            userId = partnerUserId;
            ownerId = partnerId;
            sql = """
SELECT P.ScreenCode
FROM dbo.TDADPartnerUserPermission UP
INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
INNER JOIN dbo.TDADPartnerUser U ON U.PartnerUserID=UP.PartnerUserID AND U.IsActive=1
WHERE U.PartnerUserID=@ID AND U.PartnerID=@OwnerID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW'
UNION
SELECT RP.MenuCode
FROM dbo.TDADPartnerUser U
INNER JOIN dbo.TDADPartnerUserEmployee PUE ON PUE.PartnerUserID=U.PartnerUserID
INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=PUE.EmployeeID
INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='P' AND RG.PartnerID=U.PartnerID AND RG.ProjectID=@ProjectID
INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.ActionCode='VIEW' AND RP.IsAllowed=1
WHERE U.PartnerUserID=@ID AND U.PartnerID=@OwnerID AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()));
""";
        }
        else if (userType == "COMPANY_USER")
        {
            if (LongClaim("user_id") is not long companyUserId ||
                LongClaim("company_id") is not long companyId) return [];
            userId = companyUserId;
            ownerId = companyId;
            sql = """
SELECT P.ScreenCode
FROM dbo.TDADUserPermission UP
INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
INNER JOIN dbo.TDADUser U ON U.UserID=UP.UserID AND U.IsActive=1
WHERE U.UserID=@ID AND U.CompanyID=@OwnerID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW'
UNION
SELECT RP.MenuCode
FROM dbo.TDADUser U
INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID
INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@ProjectID
INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@ProjectID AND RP.ActionCode='VIEW' AND RP.IsAllowed=1
WHERE U.UserID=@ID AND U.CompanyID=@OwnerID AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()));
""";
        }
        else
        {
            if (LongClaim("laoo_user_id") is not long laooUserId) return [];
            userId = laooUserId;
            sql = """
SELECT P.ScreenCode
FROM dbo.TDADLaooUserPermission UP
INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
INNER JOIN dbo.TDADLaooUser U ON U.LaooUserID=UP.LaooUserID AND U.IsActive=1
WHERE U.LaooUserID=@ID AND UP.ProjectID=@ProjectID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW';
""";
        }
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@ID", SqlDbType.BigInt).Value = userId;
        if (ownerId.HasValue)
            command.Parameters.Add("@OwnerID", SqlDbType.BigInt).Value = ownerId.Value;
        await using var reader = await command.ExecuteReaderAsync(token);
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        while (await reader.ReadAsync(token)) result.Add(reader.GetString(0));
        return result;
    }

    private long? LongClaim(string name) => long.TryParse(User.FindFirstValue(name), out var value) ? value : null;

    private static string? N(SqlDataReader reader, int index) => reader.IsDBNull(index) ? null : reader.GetString(index);
}
