namespace LaooApi.Services;

internal static class AuthenticationProjectAccess
{
    internal const string PartnerSql = """
        (
            u.IsPartnerAdmin = 1
            OR
            EXISTS
            (
                SELECT 1
                FROM dbo.TDADPartnerUserPermission AS directPermission
                INNER JOIN dbo.TDADPermission AS permission
                    ON permission.PermissionID = directPermission.PermissionID
                   AND permission.ProjectID = directPermission.ProjectID
                   AND permission.IsActive = 1
                WHERE directPermission.PartnerUserID = u.PartnerUserID
                  AND directPermission.ProjectID = @ProjectID
                  AND directPermission.IsAllowed = 1
                  AND directPermission.IsActive = 1
            )
            OR EXISTS
            (
                SELECT 1
                FROM dbo.TDADPartnerUserEmployee AS partnerEmployee
                INNER JOIN dbo.TDADEmployee AS employee
                    ON employee.EmployeeID = partnerEmployee.EmployeeID
                   AND employee.PartnerID = u.PartnerID
                   AND employee.IsActive = 1
                INNER JOIN dbo.TDADEmployeeRoleGroup AS employeeRole
                    ON employeeRole.EmployeeID = employee.EmployeeID
                   AND employeeRole.IsActive = 1
                   AND employeeRole.EffectiveFrom <= CONVERT(date, SYSUTCDATETIME())
                   AND (employeeRole.EffectiveTo IS NULL
                        OR employeeRole.EffectiveTo >= CONVERT(date, SYSUTCDATETIME()))
                INNER JOIN dbo.TDADRoleGroup AS roleGroup
                    ON roleGroup.RoleGroupID = employeeRole.RoleGroupID
                   AND roleGroup.ProjectID = @ProjectID
                   AND roleGroup.ScopeType = 'P'
                   AND roleGroup.PartnerID = u.PartnerID
                   AND roleGroup.IsActive = 1
                INNER JOIN dbo.TDADRoleGroupPermission AS rolePermission
                    ON rolePermission.RoleGroupID = roleGroup.RoleGroupID
                   AND rolePermission.ProjectID = @ProjectID
                   AND rolePermission.IsAllowed = 1
                WHERE partnerEmployee.PartnerUserID = u.PartnerUserID
                  AND partnerEmployee.PartnerID = u.PartnerID
                  AND partnerEmployee.IsActive = 1
            )
        )
        """;

    internal const string CompanySql = """
        (
            EXISTS
            (
                SELECT 1
                FROM dbo.TDADUserProject AS userProject
                WHERE userProject.UserID = u.UserID
                  AND userProject.CompanyID = u.CompanyID
                  AND userProject.ProjectID = @ProjectID
                  AND userProject.IsActive = 1
            )
        )
        """;
}
