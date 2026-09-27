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
