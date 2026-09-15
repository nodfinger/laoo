using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace LaooTrainingModule.Controllers;

[ApiController]
[Authorize]
[Route("api/company/training/settings")]
public sealed class TrainingSettingsController(IConfiguration configuration)
    : ControllerBase
{
    private const string ProjectCode = "LAOO_TRAINING";

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken token)
    {
        if (!TryScope(out var companyId, out var partnerId, out var userId))
            return Forbid();

        await using var connection = new SqlConnection(
            configuration.GetConnectionString("LaooDatabase"));
        await connection.OpenAsync(token);

        if (!await IsEnabledForUserAsync(
                connection, companyId, partnerId, userId, token))
            return Forbid();

        if (!await IsCompanyAdminAsync(connection, companyId, userId, token))
            return Forbid();

        return Ok(new
        {
            projectCode = ProjectCode,
            trainingEnabled = true,
            hasConfigurableSettings = false,
        });
    }

    private bool TryScope(
        out long companyId,
        out long partnerId,
        out long userId)
    {
        companyId = partnerId = userId = 0;
        return string.Equals(
                   User.FindFirstValue("user_type"),
                   "COMPANY_USER",
                   StringComparison.OrdinalIgnoreCase)
            && long.TryParse(User.FindFirstValue("company_id"), out companyId)
            && long.TryParse(User.FindFirstValue("partner_id"), out partnerId)
            && long.TryParse(User.FindFirstValue("user_id"), out userId);
    }

    private static async Task<bool> IsEnabledForUserAsync(
        SqlConnection connection,
        long companyId,
        long partnerId,
        long userId,
        CancellationToken token)
    {
        const string sql = """
SELECT CAST(CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDSTCompanySetUp C
    INNER JOIN dbo.TDADProject P
        ON P.ProjectCode=@ProjectCode AND P.IsActive=1
    INNER JOIN dbo.TDADCompanyProject CP
        ON CP.ProjectID=P.ProjectID
       AND CP.CompanyID=C.CompanyID
       AND CP.PartnerID=C.PartnerID
       AND CP.IsEnabled=1
       AND (CP.StartDate IS NULL OR CP.StartDate<=CONVERT(date,SYSUTCDATETIME()))
       AND (CP.ExpireDate IS NULL OR CP.ExpireDate>=CONVERT(date,SYSUTCDATETIME()))
    INNER JOIN dbo.TDADUserProject UP
        ON UP.ProjectID=P.ProjectID
       AND UP.CompanyID=C.CompanyID
       AND UP.UserID=@UserID
       AND UP.IsActive=1
    INNER JOIN dbo.TDADUser U
        ON U.UserID=UP.UserID
       AND U.CompanyID=UP.CompanyID
       AND U.IsActive=1
    WHERE C.CompanyID=@CompanyID
      AND C.PartnerID=@PartnerID
      AND C.IsActive=1
) THEN 1 ELSE 0 END AS bit);
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@ProjectCode", SqlDbType.NVarChar, 50).Value =
            ProjectCode;
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@PartnerID", SqlDbType.BigInt).Value = partnerId;
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = userId;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }

    private static async Task<bool> IsCompanyAdminAsync(
        SqlConnection connection,
        long companyId,
        long userId,
        CancellationToken token)
    {
        const string sql = """
SELECT CAST(CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.TDADUser
    WHERE UserID=@UserID
      AND CompanyID=@CompanyID
      AND IsActive=1
      AND IsCompanyAdmin=1
) THEN 1 ELSE 0 END AS bit);
""";
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add("@CompanyID", SqlDbType.BigInt).Value = companyId;
        command.Parameters.Add("@UserID", SqlDbType.BigInt).Value = userId;
        return Convert.ToBoolean(await command.ExecuteScalarAsync(token));
    }
}
