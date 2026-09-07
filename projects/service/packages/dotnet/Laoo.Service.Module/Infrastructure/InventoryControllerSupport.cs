using System.Data;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Infrastructure;

internal static class InventoryControllerSupport
{
    internal static long ClaimId(ClaimsPrincipal user, string name) =>
        long.TryParse(user.FindFirstValue(name), out var value) ? value : 0;

    internal static async Task<SqlConnection> OpenAsync(IConfiguration configuration, CancellationToken token)
    {
        var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);
        return connection;
    }

    internal static async Task<bool> CanAsync(SqlConnection connection, ClaimsPrincipal principal, string menuCode, string action, CancellationToken token)
    {
        const string sql = """
SELECT CASE WHEN
 EXISTS(SELECT 1 FROM dbo.TDADUser U WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1)
 OR EXISTS(SELECT 1 FROM dbo.TDADUserPermission UP JOIN dbo.TDADPermission P ON P.PermissionID=UP.PermissionID AND P.ProjectID=UP.ProjectID WHERE UP.UserID=@user AND UP.ProjectID=@project AND UP.IsAllowed=1 AND UP.IsActive=1 AND P.IsActive=1 AND P.ActionCode=@action AND P.ScreenCode=@screen)
 OR EXISTS(SELECT 1 FROM dbo.TDADUser U JOIN dbo.TDADUserEmployee UE ON UE.UserID=U.UserID JOIN dbo.TDADEmployeeRoleGroup ERG ON ERG.EmployeeID=UE.EmployeeID JOIN dbo.TDADRoleGroup RG ON RG.RoleGroupID=ERG.RoleGroupID AND RG.ScopeType=N'C' AND RG.CompanyID=U.CompanyID AND RG.ProjectID=@project JOIN dbo.TDADRoleGroupPermission RP ON RP.RoleGroupID=RG.RoleGroupID AND RP.ProjectID=@project AND RP.MenuCode=@screen AND RP.ActionCode=@action AND RP.IsAllowed=1 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND ERG.IsActive=1 AND ERG.EffectiveFrom<=CONVERT(date,SYSUTCDATETIME()) AND (ERG.EffectiveTo IS NULL OR ERG.EffectiveTo>=CONVERT(date,SYSUTCDATETIME())))
 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command,"@user",SqlDbType.BigInt,ClaimId(principal,"user_id"));
        Add(command,"@company",SqlDbType.BigInt,ClaimId(principal,"company_id"));
        Add(command,"@project",SqlDbType.BigInt,ClaimId(principal,"project_id"));
        Add(command,"@screen",SqlDbType.NVarChar,menuCode,20);
        Add(command,"@action",SqlDbType.NVarChar,action,20);
        return (bool)(await command.ExecuteScalarAsync(token) ?? false);
    }

    internal static void Add(SqlCommand command, string name, SqlDbType type, object? value, int size = 0)
    {
        var parameter = command.Parameters.Add(name,type);
        if (size > 0) parameter.Size = size;
        if (type == SqlDbType.Decimal)
        {
            parameter.Precision = 18;
            parameter.Scale = 4;
        }
        parameter.Value = value ?? DBNull.Value;
    }
}
