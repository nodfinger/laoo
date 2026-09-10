using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;

namespace LaooApi.Security;

// Dedicated to the Core item catalog. Other modules keep their existing guards.
public sealed class RequireItemCatalogProjectAttribute() : TypeFilterAttribute(typeof(ItemCatalogProjectFilter));

public sealed class ItemCatalogProjectFilter(IConfiguration configuration) : IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(context.HttpContext.RequestAborted);
        if (!await ItemCatalogAuthorization.SessionAllowed(connection, context.HttpContext.User, context.HttpContext.RequestAborted))
            context.Result = new ObjectResult(new { message = "ไม่สามารถเข้าถึงทะเบียนสินค้าได้", description = "บัญชี บริษัท หรือ Project ของ Session ไม่ได้เปิดใช้งานหรืออยู่นอกขอบเขตสิทธิ์", code = "PROJECT_DISABLED" }) { StatusCode = 403 };
    }
}

public static class ItemCatalogAuthorization
{
    public const string SessionSql = """
SELECT CAST(CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADUser U
 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
 JOIN dbo.TDADPartner B ON B.PartnerID=C.PartnerID AND B.IsActive=1
 JOIN dbo.TDADCompanyProject CP ON CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.ProjectID=@project AND CP.IsEnabled=1
 JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.IsActive=1
 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND C.PartnerID=@partner
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
 AND (U.IsCompanyAdmin=1 OR EXISTS(SELECT 1 FROM dbo.TDADUserProject UP WHERE UP.UserID=U.UserID AND UP.CompanyID=U.CompanyID AND UP.ProjectID=P.ProjectID AND UP.IsActive=1))
) THEN 1 ELSE 0 END AS bit);
""";

    public static async Task<bool> SessionAllowed(SqlConnection connection, ClaimsPrincipal principal, CancellationToken token)
    {
        if (!TryScope(principal, out var scope)) return false;
        await using var command = new SqlCommand(SessionSql, connection);
        Bind(command, scope);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    public static async Task<bool> IsAllowed(SqlConnection connection, ClaimsPrincipal principal, string action, CancellationToken token)
    {
        if (!TryScope(principal, out var scope) || !await SessionAllowed(connection, principal, token)) return false;
        await using var command = new SqlCommand(PermissionSql, connection);
        Bind(command, scope); command.Parameters.Add("@action", SqlDbType.NVarChar, 20).Value = action;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    public const string PermissionSql = """
WITH Eligible AS (
 SELECT P.ProjectID FROM dbo.TDADProject P
 JOIN dbo.TDADProjectMenu PM ON PM.ProjectID=P.ProjectID AND PM.MenuCode=N'08001' AND PM.IsActive=1
 JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1
 JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=@company AND CP.PartnerID=@partner AND CP.IsEnabled=1
 WHERE P.IsActive=1 AND (P.ProjectCode=N'LAOO' OR P.ProjectID=@project)
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
 AND (@action='VIEW' OR (M.ScreenType IN(1,4) AND @action IN('CREATE','EDIT','DELETE')) OR (M.ScreenType=2 AND @action='EDIT'))
)
SELECT CAST(CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1
 AND EXISTS(SELECT 1 FROM Eligible)
 AND (U.IsCompanyAdmin=1 OR EXISTS(
   SELECT 1 FROM Eligible E JOIN dbo.TDADUserProject UP ON UP.ProjectID=E.ProjectID AND UP.CompanyID=U.CompanyID AND UP.UserID=U.UserID AND UP.IsActive=1
   WHERE EXISTS(SELECT 1 FROM dbo.TDADUserPermission DP JOIN dbo.TDADPermission P ON P.PermissionID=DP.PermissionID AND P.ProjectID=DP.ProjectID
     WHERE DP.UserID=U.UserID AND DP.ProjectID=E.ProjectID AND DP.IsActive=1 AND DP.IsAllowed=1 AND P.IsActive=1 AND P.ScreenCode IN(N'08001',N'COMPANY_PRODUCTS') AND P.ActionCode=@action)
   OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE
     JOIN dbo.TDADEmployee EMP ON EMP.EmployeeID=UE.EmployeeID AND EMP.CompanyID=U.CompanyID AND EMP.IsActive=1
     JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=EMP.EmployeeID AND ERG.IsActive=1
     JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.CompanyID=U.CompanyID AND RG.ScopeType='C' AND RG.IsActive=1
     JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=E.ProjectID AND RP.IsAllowed=1
     WHERE UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1 AND RP.MenuCode=N'08001' AND RP.ActionCode=@action
       AND (RG.ProjectID=E.ProjectID OR EXISTS(SELECT 1 FROM dbo.TDADProject Core WHERE Core.ProjectID=RG.ProjectID AND Core.ProjectCode='LAOO' AND Core.IsActive=1))
       AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
 ))) THEN 1 ELSE 0 END AS bit);
""";

    private static bool TryScope(ClaimsPrincipal user, out (long User, long Company, long Partner, long Project) scope)
    {
        scope = default;
        if (user.FindFirstValue("user_type") != "COMPANY_USER"
            || !long.TryParse(user.FindFirstValue("user_id"), out var u) || u<=0
            || !long.TryParse(user.FindFirstValue("company_id"), out var c) || c<=0
            || !long.TryParse(user.FindFirstValue("partner_id"), out var b) || b<=0
            || !long.TryParse(user.FindFirstValue("project_id"), out var p) || p<=0) return false;
        scope=(u,c,b,p); return true;
    }
    private static void Bind(SqlCommand command, (long User, long Company, long Partner, long Project) scope)
    {
        command.Parameters.Add("@user",SqlDbType.BigInt).Value=scope.User;
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=scope.Company;
        command.Parameters.Add("@partner",SqlDbType.BigInt).Value=scope.Partner;
        command.Parameters.Add("@project",SqlDbType.BigInt).Value=scope.Project;
    }
}
