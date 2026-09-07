using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Security;

internal static class MeetingFoodPlanAccess
{
    internal const string OwnershipSql = """
(B.RequesterUserID=@user OR EXISTS
 (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS
 (SELECT 1 FROM dbo.TDADMeetingRoomContact C
  INNER JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=C.EmployeeID AND UE.CompanyID=@company AND UE.UserID=@user
  INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=C.EmployeeID AND E.CompanyID=@company AND E.IsActive=1
  WHERE C.RoomID=B.RoomID AND C.IsActive=1))
""";

    internal static bool CanManage(string status, DateTime end, bool inScope, bool allowed) =>
        status == "APPROVED" && end > DateTime.Now && inScope && allowed;

    internal static async Task<bool> Allowed(SqlConnection connection, ClaimsPrincipal principal, string action, CancellationToken token)
    {
        if (principal.FindFirstValue("user_type") != "COMPANY_USER" ||
            !long.TryParse(principal.FindFirstValue("company_id"), out var company) ||
            !long.TryParse(principal.FindFirstValue("user_id"), out var user) ||
            !long.TryParse(principal.FindFirstValue("project_id"), out var project)) return false;
        const string sql = """
SELECT CASE WHEN EXISTS
 (SELECT 1 FROM dbo.TDADMainMenu WHERE MenuCode='21005'
  AND (@action='VIEW' OR ScreenType IN (1,4) OR (@action='EDIT' AND ScreenType=2)))
 AND EXISTS (SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1)
 AND (
 EXISTS (SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsCompanyAdmin=1)
 OR EXISTS
 (SELECT 1 FROM dbo.TDADUserPermission UP
  INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
  WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1
    AND P.IsActive=1 AND P.ScreenCode='21005' AND P.ActionCode=@action)
 OR EXISTS
 (SELECT 1 FROM dbo.TDADUserEmployee UE
  INNER JOIN dbo.TDADEmployee E ON E.EmployeeID=UE.EmployeeID AND E.CompanyID=@company AND E.IsActive=1
  INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
  INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C'
    AND RG.CompanyID=@company AND RG.ProjectID=@project AND RG.IsActive=1
  INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project
    AND RP.MenuCode='21005' AND RP.ActionCode=@action AND RP.IsAllowed=1
  WHERE UE.UserID=@user AND UE.CompanyID=@company
    AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
    AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))))
THEN 1 ELSE 0 END;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@company", company);
        command.Parameters.AddWithValue("@user", user);
        command.Parameters.AddWithValue("@project", project);
        command.Parameters.AddWithValue("@action", action);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
}
