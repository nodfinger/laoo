using System.Data;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooApi.Services.Assistant;

public static class AiCapabilityRoleAccess
{
    public const string PermissionPoint = "MANAGE_AI_CAPABILITY_ACCESS";

    private static long Claim(ClaimsPrincipal user, string name) =>
        long.TryParse(user.FindFirstValue(name), out var value) ? value : 0;

    public static async Task<bool> CanManage(SqlConnection db, ClaimsPrincipal user, CancellationToken token)
    {
        await using var cmd = new SqlCommand("""
SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS (SELECT 1 FROM dbo.TDADUserPermissionPoint P
 JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=P.EmployeeID AND UE.CompanyID=P.CompanyID AND UE.IsActive=1
 JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=P.CompanyID AND U.IsActive=1
 WHERE U.UserID=@user AND P.CompanyID=@company AND P.ProjectID=@project AND P.MenuCode=N'10008'
 AND P.PermissionPointCode=@point AND P.IsActive=1 AND P.IsAllowed=1) THEN 1 ELSE 0 END
""", db);
        cmd.Parameters.Add("@user", SqlDbType.BigInt).Value=Claim(user,"user_id");
        cmd.Parameters.Add("@company", SqlDbType.BigInt).Value=Claim(user,"company_id");
        cmd.Parameters.Add("@project", SqlDbType.BigInt).Value=Claim(user,"project_id");
        cmd.Parameters.Add("@point", SqlDbType.NVarChar,80).Value=PermissionPoint;
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token)) == 1;
    }

    public static async Task<bool> CanUse(SqlConnection db, ClaimsPrincipal user, string code, CancellationToken token)
    {
        await using var schema = new SqlCommand("SELECT CASE WHEN OBJECT_ID(N'dbo.TDADAiCapabilityRolePolicy',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.TDADAiCapabilityRoleAccess',N'U') IS NOT NULL THEN 1 ELSE 0 END", db);
        if (Convert.ToInt32(await schema.ExecuteScalarAsync(token)) == 0) return true;
        await using var cmd = new SqlCommand("""
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM dbo.TDADAiCapabilityRolePolicy WHERE CompanyID=@company AND CapabilityCode=@code)
 OR EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADAiCapabilityRoleAccess A
 JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=A.RoleGroupID AND RG.CompanyID=A.CompanyID AND RG.ScopeType='C' AND RG.IsActive=1
 JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.RoleGroupID=RG.RoleGroupID AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
 JOIN dbo.TDADEmployee E ON E.EmployeeID=ERG.EmployeeID AND E.CompanyID=A.CompanyID AND E.IsActive=1
 JOIN dbo.TDADUserEmployee UE ON UE.EmployeeID=E.EmployeeID AND UE.CompanyID=A.CompanyID AND UE.IsActive=1
 JOIN dbo.TDADUser U ON U.UserID=UE.UserID AND U.CompanyID=A.CompanyID AND U.IsActive=1
 WHERE A.CompanyID=@company AND A.CapabilityCode=@code AND U.UserID=@user) THEN 1 ELSE 0 END
""",db);
        cmd.Parameters.Add("@company",SqlDbType.BigInt).Value=Claim(user,"company_id");
        cmd.Parameters.Add("@user",SqlDbType.BigInt).Value=Claim(user,"user_id");
        cmd.Parameters.Add("@code",SqlDbType.NVarChar,100).Value=code;
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(token)) == 1;
    }
}
