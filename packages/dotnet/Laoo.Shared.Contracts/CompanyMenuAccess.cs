using System.Data;
using System.Data.Common;
using System.Security.Claims;

namespace Laoo.Shared.Contracts;

/// <summary>Company role membership is central; permission rows retain their target ProjectID.</summary>
public static class CompanyMenuAccess
{
    public static async Task<bool> IsAllowedAsync(DbConnection connection, ClaimsPrincipal user,
        string menu, string action, CancellationToken token)
    {
        if (user.FindFirst("user_type")?.Value != "COMPANY_USER"
            || !long.TryParse(user.FindFirst("user_id")?.Value,out var userId)
            || !long.TryParse(user.FindFirst("company_id")?.Value,out var companyId)
            || !long.TryParse(user.FindFirst("partner_id")?.Value,out var partnerId)) return false;
        await using var cmd=connection.CreateCommand();
        cmd.CommandText=Sql;
        Add(cmd,"@UserID",DbType.Int64,userId); Add(cmd,"@CompanyID",DbType.Int64,companyId);
        Add(cmd,"@PartnerID",DbType.Int64,partnerId); Add(cmd,"@MenuCode",DbType.String,menu);
        Add(cmd,"@Action",DbType.String,action);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }

    public const string Sql = """
WITH Eligible AS
(
 SELECT DISTINCT PM.ProjectID
 FROM dbo.TDADProjectMenu PM
 JOIN dbo.TDADProject P ON P.ProjectID=PM.ProjectID AND P.IsActive=1
 JOIN dbo.TDADMainMenu M ON M.MenuCode=PM.MenuCode AND M.IsActive=1
 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=@CompanyID AND C.PartnerID=@PartnerID AND C.IsActive=1
 JOIN dbo.TDADCompanyProject CP ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.IsEnabled=1
 JOIN dbo.TDADUserProject UP ON UP.ProjectID=P.ProjectID AND UP.UserID=@UserID AND UP.CompanyID=C.CompanyID AND UP.IsActive=1
 WHERE PM.MenuCode=@MenuCode AND PM.IsActive=1
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
)
SELECT CAST(CASE WHEN EXISTS
(
 SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@UserID AND U.CompanyID=@CompanyID AND U.IsActive=1
 AND EXISTS(SELECT 1 FROM Eligible)
 AND (U.IsCompanyAdmin=1
 OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP
   JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID
   JOIN Eligible E ON E.ProjectID=UP.ProjectID
   WHERE UP.UserID=U.UserID AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1
     AND P.ScreenCode=@MenuCode AND P.ActionCode=@Action)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserEmployee UE
   JOIN dbo.TDADEmployee EMP ON EMP.EmployeeID=UE.EmployeeID AND EMP.CompanyID=U.CompanyID AND EMP.IsActive=1
   JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID AND ERG.IsActive=1
   JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.CompanyID=U.CompanyID AND RG.ScopeType='C' AND RG.IsActive=1
   JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.IsAllowed=1
   JOIN Eligible E ON E.ProjectID=RP.ProjectID
   WHERE UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1
     AND RP.MenuCode=@MenuCode AND RP.ActionCode=@Action
     AND (RG.ProjectID=RP.ProjectID OR EXISTS(SELECT 1 FROM dbo.TDADProject Core WHERE Core.ProjectID=RG.ProjectID AND Core.ProjectCode=N'LAOO' AND Core.IsActive=1))
     AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
     AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))))
) THEN 1 ELSE 0 END AS bit);
""";
    private static void Add(DbCommand command,string name,DbType type,object value)
    { var p=command.CreateParameter(); p.ParameterName=name;p.DbType=type;p.Value=value;command.Parameters.Add(p); }
}
