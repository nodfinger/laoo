using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Data.SqlClient;

namespace LaooApi.Security;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class RequireCompanyFeatureAttribute : TypeFilterAttribute
{
    public RequireCompanyFeatureAttribute(string featureCode)
        : base(typeof(RequireCompanyFeatureFilter))
    {
        Arguments = [featureCode];
    }
}

public sealed class RequireCompanyFeatureFilter(
    IConfiguration configuration,
    string featureCode) : IAsyncAuthorizationFilter
{
    public async Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        var user = context.HttpContext.User;
        if (!string.Equals(
                user.FindFirstValue("user_type"),
                "COMPANY_USER",
                StringComparison.OrdinalIgnoreCase) ||
            !TryLong(user, "project_id", out var projectId) ||
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
    INNER JOIN dbo.TDADCompanyFeature CF
      ON CF.CompanyID=C.CompanyID
     AND CF.PartnerID=C.PartnerID
     AND CF.ProjectID=@ProjectID
     AND CF.FeatureCode=@FeatureCode
    INNER JOIN dbo.TDADFeature F
      ON F.FeatureCode=CF.FeatureCode
     AND F.IsActive=1
    WHERE C.CompanyID=@CompanyID
      AND C.PartnerID=@PartnerID
      AND C.IsActive=1
      AND CF.IsEnabled=1
      AND (CF.StartDate IS NULL OR CF.StartDate<=CONVERT(date, SYSUTCDATETIME()))
      AND (CF.ExpireDate IS NULL OR CF.ExpireDate>=CONVERT(date, SYSUTCDATETIME()))
) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END;
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@ProjectID", SqlDbType.BigInt).Value = projectId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@FeatureCode", SqlDbType.NVarChar, 50).Value =
            featureCode.Trim().ToUpperInvariant();
        var enabled = Convert.ToBoolean(
            await command.ExecuteScalarAsync(context.HttpContext.RequestAborted));
        if (!enabled)
            Deny(context, $"ระบบ {featureCode.Trim().ToUpperInvariant()} ยังไม่ได้เปิดใช้งานสำหรับบริษัทนี้");
    }

    private static bool TryLong(ClaimsPrincipal user, string name, out long value) =>
        long.TryParse(user.FindFirstValue(name), out value);

    private static void Deny(AuthorizationFilterContext context, string message)
    {
        context.Result = new ObjectResult(new
        {
            message,
            code = "FEATURE_DISABLED",
        })
        {
            StatusCode = StatusCodes.Status403Forbidden,
        };
    }
}
