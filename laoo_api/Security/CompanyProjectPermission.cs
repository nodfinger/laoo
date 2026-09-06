using System.Data;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooApi.Security;

internal static class CompanyProjectPermission
{
    public static async Task<bool> IsAllowedAsync(
        SqlConnection connection,
        ClaimsPrincipal principal,
        string screenCode,
        string actionCode,
        CancellationToken token)
    {
        if (!string.Equals(principal.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase)
            || !long.TryParse(principal.FindFirstValue("company_id"), out var companyId)
            || !long.TryParse(principal.FindFirstValue("user_id"), out var userId))
        {
            return false;
        }

        const string sql = """
WITH EligibleProjects AS
(
    SELECT DISTINCT PM.ProjectID
    FROM dbo.TDADProjectMenu PM
    INNER JOIN dbo.TDADProject PR ON PR.ProjectID=PM.ProjectID AND PR.IsActive=1
    INNER JOIN dbo.TDADUserProject UPR ON UPR.ProjectID=PM.ProjectID AND UPR.UserID=@UserID AND UPR.CompanyID=@CompanyID AND UPR.IsActive=1
    INNER JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=UPR.CompanyID AND C.IsActive=1
    INNER JOIN dbo.TDADCompanyProject CP
        ON CP.ProjectID=UPR.ProjectID AND CP.CompanyID=UPR.CompanyID AND CP.PartnerID=C.PartnerID
       AND CP.IsEnabled=1
       AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
       AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
    WHERE PM.MenuCode=@ScreenCode AND PM.IsActive=1
)
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADUser U
    WHERE U.UserID=@UserID AND U.CompanyID=@CompanyID AND U.IsActive=1
      AND
      (
          U.IsCompanyAdmin=1
          OR EXISTS
          (
              SELECT 1
              FROM dbo.TDADUserPermission UP
              INNER JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
              INNER JOIN EligibleProjects EP ON EP.ProjectID=UP.ProjectID
              WHERE UP.UserID=U.UserID AND UP.IsAllowed=1 AND UP.IsActive=1
                AND P.IsActive=1 AND P.ScreenCode=@ScreenCode AND P.ActionCode=@ActionCode
          )
          OR EXISTS
          (
              SELECT 1
              FROM dbo.TDADUserEmployee UE
              INNER JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
              INNER JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType='C' AND RG.CompanyID=@CompanyID AND RG.IsActive=1
              INNER JOIN EligibleProjects EP ON EP.ProjectID=RG.ProjectID
              INNER JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=RG.ProjectID
              WHERE UE.UserID=U.UserID AND UE.CompanyID=@CompanyID
                AND RP.MenuCode=@ScreenCode AND RP.ActionCode=@ActionCode AND RP.IsAllowed=1
                AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
                AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
          )
      )
      AND EXISTS(SELECT 1 FROM EligibleProjects)
) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = userId;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@ScreenCode", SqlDbType.NVarChar, 50).Value = screenCode;
        command.Parameters.Add("@ActionCode", SqlDbType.NVarChar, 30).Value = actionCode;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
}
