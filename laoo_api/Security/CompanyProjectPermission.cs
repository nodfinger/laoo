using System.Security.Claims;
using Microsoft.Data.SqlClient;

namespace LaooApi.Security;

internal static class CompanyProjectPermission
{
    public static Task<bool> IsAllowedAsync(SqlConnection connection, ClaimsPrincipal principal,
        string screenCode, string actionCode, CancellationToken token) =>
        Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(connection, principal, screenCode, actionCode, token);
}
