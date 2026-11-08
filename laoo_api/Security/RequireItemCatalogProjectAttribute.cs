using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;

namespace LaooApi.Security;

// Dedicated to the Core item catalog. Other modules keep their existing guards.
public sealed class RequireItemCatalogProjectAttribute() : TypeFilterAttribute(typeof(ItemCatalogProjectFilter));

public sealed class ItemCatalogProjectFilter(IConfiguration configuration) : IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        await using var connection = new SqlConnection(configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(context.HttpContext.RequestAborted);
        if (!await ItemCatalogAuthorization.SessionAllowed(connection, context.HttpContext.User, context.HttpContext.RequestAborted))
            context.Result = new ObjectResult(new { message = "ไม่สามารถเข้าถึงทะเบียนสินค้าได้", description = "บัญชี บริษัท หรือ Project ของ Session ไม่ได้เปิดใช้งานหรืออยู่นอกขอบเขตสิทธิ์", code = "PROJECT_DISABLED" }) { StatusCode = 403 };
    }
}

public static class ItemCatalogAuthorization
{
    public const string SessionSql = """
SELECT CAST(CASE WHEN EXISTS(
 SELECT 1 FROM dbo.TDADUser U
 JOIN dbo.TDSTCompanySetUp C ON C.CompanyID=U.CompanyID AND C.IsActive=1
 JOIN dbo.TDADPartner B ON B.PartnerID=C.PartnerID AND B.IsActive=1
 JOIN dbo.TDADCompanyProject CP ON CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID AND CP.ProjectID=@project AND CP.IsEnabled=1
 JOIN dbo.TDADProject P ON P.ProjectID=CP.ProjectID AND P.IsActive=1
 WHERE U.UserID=@user AND U.CompanyID=@company AND U.IsActive=1 AND C.PartnerID=@partner
 AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
 AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
 AND (U.IsCompanyAdmin=1 OR EXISTS(SELECT 1 FROM dbo.TDADUserProject UP WHERE UP.UserID=U.UserID AND UP.CompanyID=U.CompanyID AND UP.ProjectID=P.ProjectID AND UP.IsActive=1))
) THEN 1 ELSE 0 END AS bit);
""";

    public static async Task<bool> SessionAllowed(SqlConnection connection, ClaimsPrincipal principal, CancellationToken token)
    {
        if (!TryScope(principal, out var scope)) return false;
        await using var command = new SqlCommand(SessionSql, connection);
        Bind(command, scope);
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    public static async Task<bool> IsAllowed(SqlConnection connection, ClaimsPrincipal principal, string action, CancellationToken token)
    {
        if (!TryScope(principal, out var scope) || !await SessionAllowed(connection, principal, token)) return false;
        await using var screen = new SqlCommand("SELECT ScreenType FROM dbo.TDADMainMenu WHERE MenuCode=N'08001' AND IsActive=1", connection);
        var screenType = await screen.ExecuteScalarAsync(token);
        if (screenType is null || screenType is DBNull) return false;
        var type = Convert.ToInt32(screenType);
        if (action != "VIEW" && !(((type is 1 or 4) && (action is "CREATE" or "EDIT" or "DELETE")) || (type == 2 && action == "EDIT"))) return false;
        return await Laoo.Shared.Contracts.CompanyMenuAccess.IsAllowedAsync(connection, principal, "08001", action, token);
    }

    private static bool TryScope(ClaimsPrincipal user, out (long User, long Company, long Partner, long Project) scope)
    {
        scope = default;
        if (user.FindFirstValue("user_type") != "COMPANY_USER"
            || !long.TryParse(user.FindFirstValue("user_id"), out var u) || u<=0
            || !long.TryParse(user.FindFirstValue("company_id"), out var c) || c<=0
            || !long.TryParse(user.FindFirstValue("partner_id"), out var b) || b<=0
            || !long.TryParse(user.FindFirstValue("project_id"), out var p) || p<=0) return false;
        scope=(u,c,b,p); return true;
    }
    private static void Bind(SqlCommand command, (long User, long Company, long Partner, long Project) scope)
    {
        command.Parameters.Add("@user",SqlDbType.BigInt).Value=scope.User;
        command.Parameters.Add("@company",SqlDbType.BigInt).Value=scope.Company;
        command.Parameters.Add("@partner",SqlDbType.BigInt).Value=scope.Partner;
        command.Parameters.Add("@project",SqlDbType.BigInt).Value=scope.Project;
    }
}
