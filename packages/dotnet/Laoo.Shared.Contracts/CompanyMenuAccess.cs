using System.Data;
using System.Data.Common;
using System.Security.Claims;

namespace Laoo.Shared.Contracts;

/// <summary>Company role membership is central; permission rows retain their target ProjectID.</summary>
public static class CompanyMenuAccess
{
    public static async Task<bool> IsSalesEnabledAsync(DbConnection connection, ClaimsPrincipal user, CancellationToken token)
    {
        if (!long.TryParse(user.FindFirst("company_id")?.Value, out var companyId)
            || !long.TryParse(user.FindFirst("partner_id")?.Value, out var partnerId)) return false;
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = """
SELECT CAST(CASE WHEN EXISTS (
 SELECT 1 FROM dbo.TDADCompanyProjectSubscription S
 JOIN dbo.TDADProject P ON P.ProjectID=S.ProjectID AND P.ProjectCode=N'LAOO_TRADE' AND P.IsActive=1
 JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=P.ProjectID AND PK.IsActive=1
 JOIN dbo.TDADProjectPackageFeature PF ON PF.PackageID=PK.PackageID AND PF.FeatureCode=N'SALES' AND PF.IsEnabled=1
 WHERE S.CompanyID=@CompanyID AND S.PartnerID=@PartnerID AND S.IsCurrent=1 AND S.StatusCode IN(N'ACTIVE',N'TRIAL')
 AND S.StartDate<=CONVERT(date,SYSUTCDATETIME()) AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
) OR (NOT EXISTS(SELECT 1 FROM dbo.TDADProject WHERE ProjectCode=N'LAOO_TRADE' AND IsActive=1) AND EXISTS (SELECT 1 FROM dbo.TDADCompanyFeature CF
 JOIN dbo.TDADProject P ON P.ProjectID=CF.ProjectID AND P.ProjectCode=N'LAOO' AND P.IsActive=1
 JOIN dbo.TDADFeature F ON F.FeatureCode=CF.FeatureCode AND F.IsActive=1
 WHERE CF.CompanyID=@CompanyID AND CF.PartnerID=@PartnerID AND CF.FeatureCode=N'SALES' AND CF.IsEnabled=1
 AND (CF.StartDate IS NULL OR CF.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CF.ExpireDate IS NULL OR CF.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))) THEN 1 ELSE 0 END AS bit)
""";
        Add(cmd, "@CompanyID", DbType.Int64, companyId);
        Add(cmd, "@PartnerID", DbType.Int64, partnerId);
        return Convert.ToBoolean(await cmd.ExecuteScalarAsync(token));
    }
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

    // Restrict eligibility and the resulting action grant to the named project.
    public static async Task<bool> IsAllowedForProjectAsync(DbConnection connection, ClaimsPrincipal user,
        string projectCode, string menu, string action, CancellationToken token)
    {
        if (user.FindFirst("user_type")?.Value != "COMPANY_USER"
            || !long.TryParse(user.FindFirst("user_id")?.Value, out var userId)
            || !long.TryParse(user.FindFirst("company_id")?.Value, out var companyId)
            || !long.TryParse(user.FindFirst("partner_id")?.Value, out var partnerId)) return false;
        await using var cmd = connection.CreateCommand();
        const string eligibleClause = "WHERE PM.MenuCode=@MenuCode AND PM.IsActive=1";
        if (!Sql.Contains(eligibleClause, StringComparison.Ordinal))
            throw new InvalidOperationException("Cannot safely restrict menu permission to a project.");
        cmd.CommandText = Sql.Replace(eligibleClause,
            """
WHERE PM.MenuCode=@MenuCode AND PM.IsActive=1 AND P.ProjectCode=@ProjectCode
 AND (P.ProjectType=N'CORE' OR EXISTS
  (SELECT 1 FROM dbo.TDADCompanyProjectSubscription AI_S
   JOIN dbo.TDADProjectPackage AI_PK ON AI_PK.PackageID=AI_S.PackageID AND AI_PK.ProjectID=AI_S.ProjectID AND AI_PK.IsActive=1
   WHERE AI_S.CompanyID=@CompanyID AND AI_S.PartnerID=@PartnerID AND AI_S.ProjectID=P.ProjectID
    AND AI_S.IsCurrent=1 AND AI_S.StatusCode IN(N'ACTIVE',N'TRIAL')
    AND AI_S.StartDate<=CONVERT(date,SYSUTCDATETIME())
    AND (AI_S.ExpireDate IS NULL OR AI_S.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))))
""", StringComparison.Ordinal);
        Add(cmd, "@UserID", DbType.Int64, userId); Add(cmd, "@CompanyID", DbType.Int64, companyId);
        Add(cmd, "@PartnerID", DbType.Int64, partnerId); Add(cmd, "@ProjectCode", DbType.String, projectCode);
        Add(cmd, "@MenuCode", DbType.String, menu); Add(cmd, "@Action", DbType.String, action);
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
 WHERE PM.MenuCode=@MenuCode AND PM.IsActive=1
 AND (M.MenuGroupCode<>N'09' OR P.ProjectCode=N'LAOO_TRADE' OR EXISTS
   (SELECT 1 FROM dbo.TDADCompanyFeature CF
    JOIN dbo.TDADProject CoreProject ON CoreProject.ProjectID=CF.ProjectID AND CoreProject.ProjectCode=N'LAOO' AND CoreProject.IsActive=1
    JOIN dbo.TDADFeature F ON F.FeatureCode=CF.FeatureCode AND F.IsActive=1
    WHERE CF.PartnerID=@PartnerID AND CF.CompanyID=@CompanyID AND CF.FeatureCode=N'SALES' AND CF.IsEnabled=1
      AND (CF.StartDate IS NULL OR CF.StartDate<=CONVERT(date,SYSUTCDATETIME()))
      AND (CF.ExpireDate IS NULL OR CF.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))))
 AND
 (
   (P.ProjectType=N'CORE' AND EXISTS
    (SELECT 1 FROM dbo.TDADCompanyProject CP
     WHERE CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID
       AND CP.IsEnabled=1
       AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
       AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))))
   OR
   (P.ProjectType<>N'CORE' AND EXISTS
    (SELECT 1 FROM dbo.TDADCompanyProjectSubscription S
     JOIN dbo.TDADProjectPackage PK ON PK.PackageID=S.PackageID AND PK.ProjectID=S.ProjectID AND PK.IsActive=1
     WHERE S.CompanyID=C.CompanyID AND S.PartnerID=C.PartnerID AND S.ProjectID=P.ProjectID AND S.IsCurrent=1
       AND S.StartDate<=CONVERT(date,SYSUTCDATETIME())
       AND
       (
         (S.StatusCode IN(N'ACTIVE',N'TRIAL') AND (S.ExpireDate IS NULL OR S.ExpireDate>=CONVERT(date,SYSUTCDATETIME())))
         OR ((S.StatusCode=N'EXPIRED' OR (S.StatusCode IN(N'ACTIVE',N'TRIAL') AND S.ExpireDate<CONVERT(date,SYSUTCDATETIME())))
             AND @Action IN(N'VIEW',N'PREVIEW',N'DOWNLOAD',N'PRINT',N'EXPORT'))
       )
       AND (NULLIF(LTRIM(RTRIM(M.FeatureCode)),N'') IS NULL OR EXISTS
         (SELECT 1 FROM dbo.TDADProjectPackageFeature PF
          WHERE PF.PackageID=PK.PackageID AND PF.FeatureCode=M.FeatureCode AND PF.IsEnabled=1))))
 )
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
