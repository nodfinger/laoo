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

    internal static Task<bool> CanAsync(SqlConnection connection, ClaimsPrincipal principal, string menuCode, string action, CancellationToken token) =>
        Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(connection, principal, menuCode, action, token);

    internal static async Task<bool> CanAsync(
        SqlConnection connection,
        ClaimsPrincipal principal,
        string menuCode,
        string action,
        string permissionPointCode,
        CancellationToken token)
    {
        if (!await CanAsync(connection, principal, menuCode, action, token)) return false;

        const string sql = """
SELECT CAST(CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADUser U
    WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND U.IsCompanyAdmin=1
)
OR EXISTS
(
    SELECT 1
    FROM dbo.TDADUser U
    INNER JOIN dbo.TDADUserEmployee UE
      ON UE.UserID=U.UserID AND UE.CompanyID=U.CompanyID AND UE.IsActive=1
    INNER JOIN dbo.TDADUserPermissionPoint PP
      ON PP.EmployeeID=UE.EmployeeID AND PP.ProjectID=@project AND PP.CompanyID=@company
     AND PP.MenuCode=@menu AND PP.PermissionPointCode=@point
     AND PP.IsActive=1 AND PP.IsAllowed=1
    WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1
) THEN 1 ELSE 0 END AS bit);
""";
        await using var command = new SqlCommand(sql, connection);
        Add(command, "@user", SqlDbType.BigInt, ClaimId(principal, "user_id"));
        Add(command, "@project", SqlDbType.BigInt, ClaimId(principal, "project_id"));
        Add(command, "@company", SqlDbType.BigInt, ClaimId(principal, "company_id"));
        Add(command, "@menu", SqlDbType.NVarChar, menuCode.Trim(), 20);
        Add(command, "@point", SqlDbType.NVarChar, permissionPointCode.Trim(), 80);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
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
