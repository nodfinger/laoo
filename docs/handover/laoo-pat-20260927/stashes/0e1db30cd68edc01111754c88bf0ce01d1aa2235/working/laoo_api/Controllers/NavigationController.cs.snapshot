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
        var projects = await LoadProjectsAsync(cancellationToken);
        if (projects is null) return Forbid();
        var groups = projects
            .SelectMany(project => project.MenuGroups)
            .GroupBy(group => group.MenuGroupCode)
            .Select(group => group.First())
            .ToList();
        return Ok(groups);
    }

    [HttpGet("projects")]
    public async Task<ActionResult<List<NavigationProjectResponse>>> GetProjects(CancellationToken cancellationToken)
    {
        var projects = await LoadProjectsAsync(cancellationToken);
        return projects is null ? Forbid() : Ok(projects);
    }

    private async Task<List<NavigationProjectResponse>?> LoadProjectsAsync(CancellationToken cancellationToken)
    {
        var userType = User.FindFirstValue("user_type");
        if (userType is not ("PARTNER_USER" or "COMPANY_USER" or "LAOO_SUPPORT") ||
            LongClaim("project_id") is not long projectId)
            return null;

        await using var connection = new SqlConnection(_configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(cancellationToken);
        var admin = await IsAdminAsync(connection, userType, cancellationToken);
        var allowedFeatures = admin ? null : await LoadAllowedFeaturesAsync(connection, userType, cancellationToken);
        var audienceType = userType == "PARTNER_USER" ? "P" : userType == "COMPANY_USER" ? "C" : "L";
        const string sql = """
WITH AllowedProjects AS
(
    SELECT @ProjectID AS ProjectID
    WHERE @UserType <> N'COMPANY_USER'
    UNION
    SELECT UPR.ProjectID
    FROM dbo.TDADUserProject UPR
    INNER JOIN dbo.TDADProject PR ON PR.ProjectID=UPR.ProjectID AND PR.IsActive=1
    INNER JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=UPR.CompanyID AND C.IsActive=1
    INNER JOIN dbo.TDADCompanyProject CP
        ON CP.ProjectID=UPR.ProjectID AND CP.CompanyID=UPR.CompanyID
       AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
       AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
       AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
    WHERE @UserType=N'COMPANY_USER'
      AND UPR.UserID=@UserID AND UPR.CompanyID=@CompanyID AND UPR.IsActive=1
)
SELECT PR.ProjectID,PR.ProjectCode,PR.ProjectNameTH,PR.ProjectType,PR.IconName,
       PR.SortOrder,PR.IsExpandedDefault,
       G.MenuGroupCode, G.MenuGroupName, G.IconName AS GroupIconName, G.SortOrder AS GroupSortOrder,
       G.IsExpandedDefault, M.MenuCode, M.MenuName, M.RouteName, M.RoutePath, M.FeatureCode,
       M.IconName, M.SortOrder, M.IsFavoriteAllowed
FROM AllowedProjects AP
INNER JOIN dbo.TDADProject PR ON PR.ProjectID=AP.ProjectID AND PR.IsActive=1
INNER JOIN dbo.TDADProjectMenuGroup PG
    ON PG.ProjectID = AP.ProjectID AND PG.IsActive = 1
INNER JOIN dbo.TDADMenuGroup G
    ON G.MenuGroupCode=PG.MenuGroupCode AND G.IsActive=1
INNER JOIN dbo.TDADProjectMenu PM
    ON PM.MenuGroupCode = G.MenuGroupCode
   AND PM.ProjectID = AP.ProjectID AND PM.IsActive = 1
INNER JOIN dbo.TDADMainMenu M ON M.MenuCode = PM.MenuCode AND M.IsActive = 1 AND M.IsVisible = 1
INNER JOIN dbo.TDADMenuGroup OwnerGroup ON OwnerGroup.MenuGroupCode=M.MenuGroupCode AND OwnerGroup.IsActive=1
WHERE UPPER(LTRIM(RTRIM(G.AudienceType))) IN (N'A',@AudienceType)
  AND UPPER(LTRIM(RTRIM(OwnerGroup.AudienceType))) IN (N'A',@AudienceType)
  -- Company accounts are managed through the Person/Employee workflow.
  AND (@UserType <> N'COMPANY_USER' OR G.MenuGroupCode <> N'07')
  -- The Company branch menu remains Company-only in the shared settings group.
  AND (M.MenuCode <> N'13001' OR @UserType = N'COMPANY_USER')
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
                WHERE CF.ProjectID = AP.ProjectID
                  AND CF.CompanyID = @CompanyID
                  AND CF.FeatureCode = M.FeatureCode
                  AND CF.IsEnabled = 1
                  AND (CF.StartDate IS NULL OR CF.StartDate <= CONVERT(date, SYSUTCDATETIME()))
                  AND (CF.ExpireDate IS NULL OR CF.ExpireDate >= CONVERT(date, SYSUTCDATETIME()))
            )
        )
      )
ORDER BY PR.SortOrder,PG.SortOrder,PM.SortOrder,M.MenuCode;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@AudienceType", SqlDbType.Char).Value = audienceType;
        command.Parameters.Add("@UserType", SqlDbType.NVarChar, 30).Value = userType;
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = LongClaim("company_id") is long companyId ? companyId : DBNull.Value;
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = LongClaim("user_id") is long userId ? userId : DBNull.Value;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var all = new List<(NavigationProjectResponse Project, NavigationMenuGroupResponse Group, NavigationMenuItemResponse Item)>();
        while (await reader.ReadAsync(cancellationToken))
        {
            var project = new NavigationProjectResponse { ProjectId = reader.GetInt64(0), ProjectCode = reader.GetString(1), ProjectName = reader.GetString(2), ProjectType = reader.GetString(3), IconName = N(reader, 4), SortOrder = reader.GetInt32(5), IsExpandedDefault = reader.GetBoolean(6) };
            var group = new NavigationMenuGroupResponse { MenuGroupCode = reader.GetString(7).Trim(), MenuGroupName = reader.GetString(8), IconName = N(reader, 9), SortOrder = reader.GetInt32(10), IsExpandedDefault = reader.GetBoolean(11) };
            var item = new NavigationMenuItemResponse { MenuCode = reader.GetString(12), MenuName = reader.GetString(13), RouteName = N(reader, 14), RoutePath = N(reader, 15), FeatureCode = N(reader, 16), IconName = N(reader, 17), SortOrder = reader.GetInt32(18), IsFavoriteAllowed = reader.GetBoolean(19) };
            if (admin || allowedFeatures!.Contains(item.MenuCode))
                all.Add((project, group, item));
        }

        return all
            .GroupBy(x => x.Project.ProjectId)
            .Select(projectRows =>
            {
                var project = projectRows.First().Project;
                project.MenuGroups.AddRange(projectRows
                    .GroupBy(x => x.Group.MenuGroupCode)
                    .Select(groupRows =>
                    {
                        var group = groupRows.First().Group;
                        group.Items.AddRange(groupRows
                            .GroupBy(x => x.Item.MenuCode)
                            .Select(items => items.First().Item));
                        return group;
                    }));
                return project;
            })
            .OrderBy(project => project.SortOrder)
            .ToList();
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
INNER JOIN dbo.TDADUserProject UPR ON UPR.UserID=U.UserID AND UPR.CompanyID=U.CompanyID AND UPR.ProjectID=UP.ProjectID AND UPR.IsActive=1
WHERE U.UserID=@ID AND U.CompanyID=@OwnerID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode='VIEW'
UNION
SELECT RP.MenuCode
FROM dbo.TDADUser U
INNER JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1
INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=U.CompanyID AND E.IsActive=1
INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID
INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=U.CompanyID AND RG.IsActive=1
INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ActionCode='VIEW' AND RP.IsAllowed=1
INNER JOIN dbo.TDADUserProject UPR ON UPR.UserID=U.UserID AND UPR.CompanyID=U.CompanyID AND UPR.ProjectID=RP.ProjectID AND UPR.IsActive=1
WHERE U.UserID=@ID AND U.CompanyID=@OwnerID AND U.IsActive=1 AND ERG.IsActive=1
 AND (RG.ProjectID=RP.ProjectID OR EXISTS(SELECT 1 FROM dbo.TDADProject Core WHERE Core.ProjectID=RG.ProjectID AND Core.ProjectCode='LAOO' AND Core.IsActive=1))
 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()));
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
