using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Security;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class RequireCompanyProjectAttribute : TypeFilterAttribute
{
    public RequireCompanyProjectAttribute(string projectCode)
        : base(typeof(RequireCompanyProjectFilter))
    {
        Arguments = [projectCode];
    }
}

public sealed class RequireCompanyProjectFilter(
    IConfiguration configuration,
    string projectCode) : IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;
        if (!string.Equals(user.FindFirstValue("user_type"), "COMPANY_USER", StringComparison.OrdinalIgnoreCase) ||
            !TryLong(user, "user_id", out var userId) ||
            !TryLong(user, "partner_id", out var partnerId) ||
            !TryLong(user, "company_id", out var companyId))
        {
            Deny(context, "บัญชีนี้ไม่มีขอบเขต Company สำหรับระบบที่ร้องขอ");
            return;
        }

        await using var connection = new SqlConnection(
            configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(context.HttpContext.RequestAborted);
        const string sql = """
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDSTCompanySetUp C
    INNER JOIN dbo.TDADProject P ON P.ProjectCode=@ProjectCode AND P.IsActive=1
    INNER JOIN dbo.TDADCompanyProject CP
      ON CP.ProjectID=P.ProjectID AND CP.CompanyID=C.CompanyID AND CP.PartnerID=C.PartnerID
     AND CP.IsEnabled=1
     AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
     AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
    INNER JOIN dbo.TDADUserProject UP
      ON UP.ProjectID=P.ProjectID AND UP.CompanyID=C.CompanyID AND UP.UserID=@UserID AND UP.IsActive=1
    WHERE C.CompanyID=@CompanyID AND C.PartnerID=@PartnerID AND C.IsActive=1
) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@ProjectCode", SqlDbType.NVarChar, 50).Value =
            projectCode.Trim().ToUpperInvariant();
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = userId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        if (!Convert.ToBoolean(
                await command.ExecuteScalarAsync(context.HttpContext.RequestAborted)))
            Deny(context, $"ระบบ {projectCode.Trim().ToUpperInvariant()} ยังไม่ได้เปิดใช้งานสำหรับผู้ใช้นี้");
    }

    private static bool TryLong(ClaimsPrincipal user, string name, out long value) =>
        long.TryParse(user.FindFirstValue(name), out value);

    private static void Deny(AuthorizationFilterContext context, string message)
    {
        context.Result = new ObjectResult(new { message, code = "PROJECT_DISABLED" })
        {
            StatusCode = StatusCodes.Status403Forbidden,
        };
    }
}
