namespace Laoo.Shared.Contracts;

/// <summary>
/// Derives Company project membership from the current administrator flag and permissions.
/// Callers must also enforce Company/package eligibility and the requested menu/action.
/// User/project rows are preferences and provisioning metadata, not a second permission grant.
/// </summary>
public static class CompanyProjectAccess
{
    // Arguments are source-code SQL expressions only; never pass request values here.
    public static string ForUser(string userAlias, string projectId, bool allowCoreShell = false)
    {
        var coreShell = allowCoreShell
            ? $"OR EXISTS(SELECT 1 FROM dbo.TDADProject Shell WHERE Shell.ProjectID={projectId} AND Shell.ProjectCode=N'LAOO' AND Shell.IsActive=1)"
            : string.Empty;
        return $$"""
(
 {{userAlias}}.IsActive=1 AND
 (
  {{userAlias}}.IsCompanyAdmin=1
  {{coreShell}}
  OR EXISTS
  (
   SELECT 1 FROM dbo.TDADUserPermission AccessDirect
   JOIN dbo.TDADPermission AccessPermission ON AccessPermission.PermissionID=AccessDirect.PermissionID
    AND AccessPermission.ProjectID=AccessDirect.ProjectID AND AccessPermission.IsActive=1
   WHERE AccessDirect.UserID={{userAlias}}.UserID AND AccessDirect.ProjectID={{projectId}}
    AND AccessDirect.IsActive=1 AND AccessDirect.IsAllowed=1 AND AccessPermission.ActionCode=N'VIEW'
  )
  OR EXISTS
  (
   SELECT 1 FROM dbo.TDADUserEmployee AccessUE
   JOIN dbo.TDADEmployee AccessEmployee ON AccessEmployee.EmployeeID=AccessUE.EmployeeID
    AND AccessEmployee.CompanyID={{userAlias}}.CompanyID AND AccessEmployee.IsActive=1
   JOIN dbo.TDADEmployeeRoleGroup AccessERG ON AccessERG.EmployeeID=AccessEmployee.EmployeeID AND AccessERG.IsActive=1
   JOIN dbo.TDADRoleGroup AccessRole ON AccessRole.RoleGroupID=AccessERG.RoleGroupID
    AND AccessRole.CompanyID={{userAlias}}.CompanyID AND AccessRole.ScopeType=N'C' AND AccessRole.IsActive=1
   JOIN dbo.TDADRoleGroupPermission AccessRP ON AccessRP.RoleGroupID=AccessRole.RoleGroupID
    AND AccessRP.ProjectID={{projectId}} AND AccessRP.IsAllowed=1 AND AccessRP.ActionCode=N'VIEW'
   WHERE AccessUE.UserID={{userAlias}}.UserID AND AccessUE.CompanyID={{userAlias}}.CompanyID AND AccessUE.IsActive=1
    AND (AccessRole.ProjectID=AccessRP.ProjectID OR EXISTS
     (SELECT 1 FROM dbo.TDADProject AccessCore WHERE AccessCore.ProjectID=AccessRole.ProjectID AND AccessCore.ProjectCode=N'LAOO' AND AccessCore.IsActive=1))
    AND AccessERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME())
    AND (AccessERG.EffectiveTo IS NULL OR AccessERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME()))
  )
 )
)
""";
    }
}
