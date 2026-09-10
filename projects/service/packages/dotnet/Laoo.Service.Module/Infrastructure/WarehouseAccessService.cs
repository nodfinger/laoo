using System.Data;
using Microsoft.Data.SqlClient;

namespace LaooServiceModule.Infrastructure;

internal static class WarehouseAccessService
{
    internal const string WarehouseAliasPredicate = """
(
    EXISTS
    (
        SELECT 1 FROM dbo.TDADUser AU
        WHERE AU.UserID=@user AND AU.CompanyID=@company AND AU.IsActive=1
          AND
          (
            AU.IsCompanyAdmin=1
            OR
            (
              (B.AccessModeCode=N'ALL' OR EXISTS
        (
            SELECT 1 FROM dbo.TDADUserBranch UB
            WHERE UB.CompanyID=@company AND UB.BranchID=B.BranchID AND UB.UserID=@user AND UB.IsActive=1
        ))
              AND
              (W.AccessModeCode=N'INHERIT' OR EXISTS
        (
            SELECT 1 FROM dbo.TDIVUserWarehouse UW
            WHERE UW.CompanyID=@company AND UW.WarehouseID=W.WarehouseID AND UW.UserID=@user AND UW.IsActive=1
        ))
            )
          )
    )
)
""";

    internal static async Task<bool> CanAccessAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        long companyId,
        long userId,
        long warehouseId,
        CancellationToken token)
    {
        var sql = $"""
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDIVWarehouse W
    INNER JOIN dbo.TDADBranch B ON B.BranchID=W.BranchID AND B.CompanyID=W.CompanyID AND B.IsActive=1
    WHERE W.CompanyID=@company AND W.WarehouseID=@warehouse AND W.IsActive=1
      AND {WarehouseAliasPredicate}
) THEN 1 ELSE 0 END;
""";
        await using var command = new SqlCommand(sql, connection, transaction);
        Add(command, "@company", companyId);
        Add(command, "@user", userId);
        Add(command, "@warehouse", warehouseId);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 1;
    }

    internal static async Task<bool> IsCompanyAdminAsync(
        SqlConnection connection,
        long companyId,
        long userId,
        CancellationToken token,
        SqlTransaction? transaction = null)
    {
        await using var command = new SqlCommand(
            "SELECT CASE WHEN EXISTS(SELECT 1 FROM dbo.TDADUser WHERE UserID=@user AND CompanyID=@company AND IsActive=1 AND IsCompanyAdmin=1) THEN 1 ELSE 0 END",
            connection,
            transaction);
        Add(command, "@company", companyId);
        Add(command, "@user", userId);
        return Convert.ToInt32(await command.ExecuteScalarAsync(token)) == 1;
    }

    private static void Add(SqlCommand command, string name, long value) =>
        command.Parameters.Add(name, SqlDbType.BigInt).Value = value;
}
